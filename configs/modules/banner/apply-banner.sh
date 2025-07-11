#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Script to apply a standard warning banner to /etc/issue.net

ISSUE_NET_FILE="/etc/issue.net"
BACKUP_FILE="/etc/issue.net.bak_$(date +%Y%m%d_%H%M%S)"

echo "Backing up current banner file (if exists) to $BACKUP_FILE..."
if [ -f "$ISSUE_NET_FILE" ]; then
    sudo cp "$ISSUE_NET_FILE" "$BACKUP_FILE"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to backup $ISSUE_NET_FILE. Aborting."
        exit 1
    fi
fi

echo "Writing warning banner to $ISSUE_NET_FILE..."

# Define the banner content using cat and EOF
sudo bash -c "cat > $ISSUE_NET_FILE" << EOF
*******************************************************************************
*                                                                             *
*                      ** WARNING - Authorized Access Only **                 *
*                                                                             *
* This system is restricted to authorized users only. All activities on this  *
* system are logged and monitored. Unauthorized access or use may result in   *
* disciplinary action and/or civil and criminal penalties.                    *
*                                                                             *
* By proceeding, you acknowledge and consent to these terms.                  *
*                                                                             *
*******************************************************************************

EOF
# Note: An empty line is added at the end by default, which is standard.

if [ $? -ne 0 ]; then
    echo "Error: Failed to write banner to $ISSUE_NET_FILE. Aborting."
    # Optional: Restore backup?
    # if [ -f "$BACKUP_FILE" ]; then
    #     echo "Restoring backup..."
    #     sudo cp "$BACKUP_FILE" "$ISSUE_NET_FILE"
    # fi
    exit 1
fi

# Set permissions - typically read-only for root, readable by others
sudo chown root:root "$ISSUE_NET_FILE"
sudo chmod 644 "$ISSUE_NET_FILE"

echo "Banner applied successfully to $ISSUE_NET_FILE."
echo "Note: This banner typically appears *before* login for network connections."
echo "For a banner *after* login, configure /etc/motd."
