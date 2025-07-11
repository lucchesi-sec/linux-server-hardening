#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Script to apply basic auditd rules using a standard approach

RULES_DIR="/etc/audit/rules.d"
OUR_RULES_FILE_BASENAME="99-hardening-rules.rules"
TARGET_RULES_FILE_SRC="${RULES_DIR}/${OUR_RULES_FILE_BASENAME}"

# Backup existing source rules file if it exists
if [ -f "$TARGET_RULES_FILE_SRC" ]; then
    BACKUP_AUDIT_RULES_FILE="${TARGET_RULES_FILE_SRC}.bak_$(date +%Y%m%d_%H%M%S)"
    echo "Backing up existing $TARGET_RULES_FILE_SRC to $BACKUP_AUDIT_RULES_FILE..."
    sudo cp "$TARGET_RULES_FILE_SRC" "$BACKUP_AUDIT_RULES_FILE"
fi

echo "Creating/Overwriting audit rules source file: $TARGET_RULES_FILE_SRC"
# Create the rules file content
sudo bash -c "cat > $TARGET_RULES_FILE_SRC" << EOF
# Auditd rules for hardening (Lucchesi-Sec)

# Monitor changes to user/group files
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# Monitor changes to login definitions
-w /etc/login.defs -p wa -k login
-w /etc/securetty -p wa -k login
-w /etc/pam.d/ -p wa -k login

# Monitor changes to SSH configuration
-w /etc/ssh/sshd_config -p wa -k sshd

# Monitor use of privileged commands (example: sudo)
-a always,exit -F path=/usr/bin/sudo -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged

# Monitor module loading/unloading
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules

# Monitor mount operations
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts
-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts

# Monitor failed access attempts (using openat)
-a always,exit -F arch=b64 -S openat,truncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S openat,truncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b64 -S openat,truncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S openat,truncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access

# Make the configuration immutable - THIS MUST BE THE LAST RULE LOADED.
-e 2
EOF

if [ $? -ne 0 ]; then
    echo "Error: Failed to write audit rules to $TARGET_RULES_FILE_SRC. Aborting."
    exit 1
fi
echo "Audit rules source file written to $TARGET_RULES_FILE_SRC."

echo "Attempting to load audit rules..."

# Ensure auditd is running before attempting to load rules via augenrules or restart
if ! sudo systemctl is-active --quiet auditd; then
    echo "auditd service is not active, attempting to start it..."
    sudo systemctl start auditd
    sleep 1 # Give it a moment
fi

# Clear any currently loaded rules in the kernel.
# This should work if rules are not immutable (e.g., after a fresh reboot before auditd loads immutable rules).
echo "Attempting to delete currently loaded kernel audit rules with 'auditctl -D'..."
if sudo auditctl -D; then
    echo "auditctl -D successful (existing rules cleared or no rules were loaded)."
else
    echo "Warning: 'auditctl -D' failed. This is problematic if rules are already loaded and immutable."
    echo "This script might fail to apply new rules if the current configuration is locked."
fi

# Load rules using augenrules (standard method)
echo "Running 'augenrules --load' to compile and load rules..."
set +e # Allow augenrules to fail so we can capture its output/status
AUGENRULES_OUTPUT=$(sudo augenrules --load 2>&1)
AUGENRULES_EXIT_CODE=$?
set -e

if [ "$AUGENRULES_EXIT_CODE" -eq 0 ]; then
    echo "augenrules --load reported success."
    RULES_APPLIED_CORRECTLY=1
else
    echo "ERROR: 'augenrules --load' failed with exit code $AUGENRULES_EXIT_CODE."
    echo "augenrules output:"
    echo "$AUGENRULES_OUTPUT"
    echo "Attempting a fallback by restarting auditd service..."
    set +e
    sudo systemctl restart auditd
    RESTART_EXIT_CODE=$?
    set -e
    if [ "$RESTART_EXIT_CODE" -eq 0 ]; then
        echo "auditd service restarted. Rules *might* have been loaded from compiled /etc/audit/audit.rules."
        echo "Checking status..."
        # Check if rules are loaded and immutable after restart
        if sudo auditctl -s | grep -q "enabled 2"; then
            echo "Post-restart check: Audit rules ARE immutable (enabled 2)."
            RULES_APPLIED_CORRECTLY=1
        else
            echo "Post-restart check: Audit rules are NOT immutable. Rule application likely failed."
            RULES_APPLIED_CORRECTLY=0
        fi
    else
        echo "ERROR: Fallback restart of auditd also failed."
        RULES_APPLIED_CORRECTLY=0
    fi
fi

if [ "$RULES_APPLIED_CORRECTLY" -eq 1 ]; then
    echo "Audit rules successfully applied and should be active and immutable."
    echo "Final loaded rules:"
    sudo auditctl -l
    sudo auditctl -s
else
    echo "ERROR: Failed to apply auditd rules correctly."
    exit 1
fi

echo "apply-auditd-rules.sh completed."
exit 0
