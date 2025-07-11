#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# DEFENSIVE AUTOMATION: Hardening SSH configuration to prevent unauthorized access
# Script to apply secure SSH configurations

SSH_CONFIG_FILE="/etc/ssh/sshd_config"
BACKUP_FILE="/etc/ssh/sshd_config.bak_$(date +%Y%m%d_%H%M%S)"

echo "Backing up current SSH configuration to $BACKUP_FILE..."
sudo cp "$SSH_CONFIG_FILE" "$BACKUP_FILE"
if [ $? -ne 0 ]; then
    echo "Error: Failed to backup SSH configuration. Aborting."
    exit 1
fi

echo "Applying secure SSH settings..."

# Helper function to set a config value
# Ensures the line is present and set, removing old versions
set_ssh_config() {
    local key="$1"
    local value="$2"
    local config_file="$3"
    echo "Setting $key to $value..."
    # Remove existing occurrences of the key (commented or not), more robustly
    sudo sed -i -E -e "/^#*\s*$key\s+.*/d" "$config_file"
    # Add the new key-value pair
    echo "$key $value" | sudo tee -a "$config_file" > /dev/null
}

# Disable Password Authentication (use key-based auth)
set_ssh_config "PasswordAuthentication" "no" "$SSH_CONFIG_FILE"
set_ssh_config "ChallengeResponseAuthentication" "no" "$SSH_CONFIG_FILE" # Also disable challenge-response

# Disable Root Login
set_ssh_config "PermitRootLogin" "no" "$SSH_CONFIG_FILE"

# Set LoginGraceTime (time allowed to authenticate)
set_ssh_config "LoginGraceTime" "60" "$SSH_CONFIG_FILE"

# Limit Max Authentication Attempts
set_ssh_config "MaxAuthTries" "3" "$SSH_CONFIG_FILE"

# Ensure some common defaults that might be missing or misconfigured
set_ssh_config "PubkeyAuthentication" "yes" "$SSH_CONFIG_FILE" # Ensure pubkey auth is enabled

# Set the SSH Banner
set_ssh_config "Banner" "/etc/issue.net" "$SSH_CONFIG_FILE"

# Disable X11 Forwarding (security risk)
set_ssh_config "X11Forwarding" "no" "$SSH_CONFIG_FILE"

# --- Optional Recommended Settings ---
# Uncomment and modify as needed

# Change Default Port (e.g., to 2222) - Requires firewall adjustment!
# PORT_VALUE="2222"
# echo "Changing SSH port to $PORT_VALUE..."
# set_ssh_config "Port" "$PORT_VALUE" "$SSH_CONFIG_FILE"
# echo "Remember to allow port $PORT_VALUE in your firewall (e.g., sudo ufw allow $PORT_VALUE/tcp)"


# Allow only specific users/groups
# echo "Restricting SSH access (example: only allow user 'adminuser')..."
# # Note: Using set_ssh_config for AllowUsers/AllowGroups might append multiple lines if run repeatedly without clearing old ones.
# # For these, ensure you clear previous AllowUsers/AllowGroups lines if you intend to replace them, or manage them carefully.
# # A simple append is shown here for demonstration.
# # sudo sed -i '/^#*AllowUsers /d' "$SSH_CONFIG_FILE" # Example: remove old AllowUsers
# echo "AllowUsers adminuser" | sudo tee -a "$SSH_CONFIG_FILE" > /dev/null
# # OR restrict by group:
# # sudo sed -i '/^#*AllowGroups /d' "$SSH_CONFIG_FILE" # Example: remove old AllowGroups
# echo "AllowGroups sshusers" | sudo tee -a "$SSH_CONFIG_FILE" > /dev/null
# Make sure the group 'sshusers' exists and users are added to it.

# Stronger Crypto (Modern Recommendations - May break compatibility with older clients)
# echo "Applying stronger cryptographic settings..."
# # For multi-line or complex settings, appending directly might be simpler,
# # but ensure they are not duplicated if the script is run multiple times.
# # Consider adding a marker and replacing a block if re-runnability is key for these.
# echo "" | sudo tee -a "$SSH_CONFIG_FILE" > /dev/null
# echo "# Stronger Crypto Settings (ensure not duplicated if script re-run)" | sudo tee -a "$SSH_CONFIG_FILE" > /dev/null
# echo "KexAlgorithms curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256" | sudo tee -a "$SSH_CONFIG_FILE" > /dev/null
# echo "Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr" | sudo tee -a "$SSH_CONFIG_FILE" > /dev/null
# echo "MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com" | sudo tee -a "$SSH_CONFIG_FILE" > /dev/null

# --- End Optional Settings ---

echo "Ensuring SSH privilege separation directory exists..."
sudo mkdir -p /run/sshd
sudo chmod 0755 /run/sshd

echo "Validating SSH configuration..."
sudo sshd -t
if [ $? -ne 0 ]; then
    echo "Error: SSH configuration validation failed. Check $SSH_CONFIG_FILE."
    echo "Restoring backup from $BACKUP_FILE..."
    sudo cp "$BACKUP_FILE" "$SSH_CONFIG_FILE"
    exit 1
fi

echo "Restarting SSH service to apply changes..."
sudo systemctl restart ssh
if [ $? -ne 0 ]; then
    echo "Warning: Failed to restart ssh service. Please check manually."
    exit 1
fi

echo "SSH configuration applied successfully."
echo "IMPORTANT: Ensure you have SSH key-based authentication set up BEFORE disabling password authentication if you haven't already."
