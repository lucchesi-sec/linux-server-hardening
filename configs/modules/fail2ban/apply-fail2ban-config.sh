#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Script to apply basic Fail2Ban configuration

JAIL_LOCAL="/etc/fail2ban/jail.local"
JAIL_CONF="/etc/fail2ban/jail.conf" # Source for defaults

echo "Checking if $JAIL_LOCAL exists..."
if [ -f "$JAIL_LOCAL" ]; then
    BACKUP_FILE="${JAIL_LOCAL}.bak_$(date +%Y%m%d_%H%M%S)"
    echo "Backing up existing $JAIL_LOCAL to $BACKUP_FILE..."
    sudo cp "$JAIL_LOCAL" "$BACKUP_FILE"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to backup Fail2Ban configuration. Aborting."
        exit 1
    fi
else
    echo "$JAIL_LOCAL does not exist. Creating it."
    # Copy jail.conf to jail.local if it doesn't exist,
    # otherwise create an empty file to add specific overrides.
    # Copying is safer as it preserves defaults we don't explicitly override.
    if [ -f "$JAIL_CONF" ]; then
        sudo cp "$JAIL_CONF" "$JAIL_LOCAL"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to copy $JAIL_CONF to $JAIL_LOCAL. Aborting."
            exit 1
        fi
    else
         echo "Warning: $JAIL_CONF not found. Creating an empty $JAIL_LOCAL."
         sudo touch "$JAIL_LOCAL"
         if [ $? -ne 0 ]; then
            echo "Error: Failed to create $JAIL_LOCAL. Aborting."
            exit 1
        fi
    fi
fi

echo "Applying SSH jail settings to $JAIL_LOCAL..."

# Ensure [sshd] section exists
if ! grep -qE "^\[sshd\]" "$JAIL_LOCAL"; then
    echo "[sshd] section not found. Adding it to the end of the file."
    echo -e "\n[sshd]" | sudo tee -a "$JAIL_LOCAL" > /dev/null
else
    echo "[sshd] section found."
fi

# Remove any existing 'enabled = ...' line under the [sshd] section.
# This sed command operates on the range from '[sshd]' to the next section or EOF.
# Inside this range, it deletes lines starting with 'enabled' (possibly commented).
echo "Removing old 'enabled' setting under [sshd] if present."
sudo sed -i '/^\[sshd\]/,/^\s*\[/{/^[#\s]*enabled\s*=/Id;}' "$JAIL_LOCAL"

# Add 'enabled = true' right after the [sshd] line.
# This ensures it's placed correctly within the section.
echo "Setting 'enabled = true' under [sshd]."
sudo sed -i '/^\[sshd\]/a enabled = true' "$JAIL_LOCAL"


# Optional: Add/Modify other settings like bantime, findtime, maxretry
# Example: Increase bantime to 1 hour
# sudo sed -i '/^\[DEFAULT\]/,/^\[/{s/^[# ]*bantime[[:space:]]*=.*$/bantime = 1h/}' "$JAIL_LOCAL"
# Check if bantime exists in [DEFAULT], if not add it
# if ! sudo awk '/^\[DEFAULT\]/{f=1} f && /bantime/{print; f=0}' "$JAIL_LOCAL" | grep -q "bantime"; then
#     sudo sed -i '/^\[DEFAULT\]/a bantime = 1h' "$JAIL_LOCAL"
# fi

# Example: Set maxretry to 3
# sudo sed -i '/^\[DEFAULT\]/,/^\[/{s/^[# ]*maxretry[[:space:]]*=.*$/maxretry = 3/}' "$JAIL_LOCAL"
# Check if maxretry exists in [DEFAULT], if not add it
# if ! sudo awk '/^\[DEFAULT\]/{f=1} f && /maxretry/{print; f=0}' "$JAIL_LOCAL" | grep -q "maxretry"; then
#     sudo sed -i '/^\[DEFAULT\]/a maxretry = 3' "$JAIL_LOCAL"
# fi

echo "Restarting Fail2Ban service..."
sudo systemctl restart fail2ban
if [ $? -ne 0 ]; then
    echo "Warning: Failed to restart fail2ban service. Please check manually."
    exit 1
fi

echo "Fail2Ban configuration applied successfully."
