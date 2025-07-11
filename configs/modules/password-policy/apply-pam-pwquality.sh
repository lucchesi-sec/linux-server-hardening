#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Script to apply password complexity and aging policies

COMMON_PASSWORD_FILE="/etc/pam.d/common-password"
LOGIN_DEFS_FILE="/etc/login.defs"

echo "Backing up $COMMON_PASSWORD_FILE..."
sudo cp "$COMMON_PASSWORD_FILE" "${COMMON_PASSWORD_FILE}.bak_$(date +%Y%m%d_%H%M%S)"

echo "Backing up $LOGIN_DEFS_FILE..."
sudo cp "$LOGIN_DEFS_FILE" "${LOGIN_DEFS_FILE}.bak_$(date +%Y%m%d_%H%M%S)"

# --- Configure Password Complexity (pam_pwquality.so) ---
echo "Configuring password complexity in $COMMON_PASSWORD_FILE..."

# Define the desired pam_pwquality.so line
# Targeting minlen=14, dcredit=-1, ucredit=-1, lcredit=-1, ocredit=-1, difok=3, retry=3
PWQUALITY_LINE="password requisite pam_pwquality.so retry=3 minlen=14 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1"
# For stricter policy including 'enforce_for_root':
# PWQUALITY_LINE="password requisite pam_pwquality.so retry=3 minlen=14 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 enforce_for_root"

# Remove existing pam_pwquality.so lines (commented or not) to avoid duplicates
sudo sed -i -e '/^#*\s*password\s\+.*\s\+pam_pwquality\.so/d' "$COMMON_PASSWORD_FILE"

# Add the new pam_pwquality.so line.
# It's typically added before pam_unix.so or pam_deny.so in the 'password' stack.
# We'll try to insert it before the first occurrence of 'pam_unix.so' in the password stack.
# If pam_unix.so is not found, append it (less ideal, but better than nothing).
if sudo grep -q "^password.*pam_unix\.so" "$COMMON_PASSWORD_FILE"; then
    echo "Found pam_unix.so, inserting pwquality line before it."
    sudo sed -i "/^password.*pam_unix\.so/i $PWQUALITY_LINE" "$COMMON_PASSWORD_FILE"
else
    echo "pam_unix.so not found in password stack, appending pwquality line. Manual check might be needed."
    echo "$PWQUALITY_LINE" | sudo tee -a "$COMMON_PASSWORD_FILE" > /dev/null
fi

echo "Password complexity rules applied to $COMMON_PASSWORD_FILE."

# --- Configure Password Aging Policies (/etc/login.defs) ---
echo "Configuring password aging policies in $LOGIN_DEFS_FILE..."

# Helper function to set a value in login.defs
set_login_defs() {
    local key="$1"
    local value="$2"
    echo "Setting $key to $value in $LOGIN_DEFS_FILE..."
    # If key exists (commented or not), replace it
    if sudo grep -qE "^#*\s*$key\s+" "$LOGIN_DEFS_FILE"; then
        sudo sed -i -E -e "s|^#*\s*($key\s+).*|\1$value|" "$LOGIN_DEFS_FILE"
    else
        # If key doesn't exist, add it
        echo "$key $value" | sudo tee -a "$LOGIN_DEFS_FILE" > /dev/null
    fi
}

set_login_defs "PASS_MAX_DAYS" "90"
set_login_defs "PASS_MIN_DAYS" "7"
set_login_defs "PASS_WARN_AGE" "14"

# Optional: Configure settings for SHA512 password hashing (default on modern Ubuntu)
# set_login_defs "ENCRYPT_METHOD" "SHA512"
# Optional: Configure umask (though often set elsewhere like /etc/profile)
# set_login_defs "UMASK" "027"

echo "Password aging policies applied to $LOGIN_DEFS_FILE."
echo "Password policy scripts completed."
echo "Note: Existing users are not affected by PASS_MIN_DAYS until their next password change."
echo "Consider using 'chage' command to enforce policies on existing users if needed."
