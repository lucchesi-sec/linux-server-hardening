#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Script to install essential hardening packages

echo "Updating package lists..."
sudo apt update

echo "Installing ufw (firewall)..."
sudo apt install -y ufw

echo "Installing fail2ban (intrusion prevention)..."
sudo apt install -y fail2ban

echo "Installing auditd (auditing daemon)..."
sudo apt install -y auditd

echo "Installing unattended-upgrades (automatic updates)..."
sudo apt install -y unattended-upgrades
echo "Enabling automatic reboot for unattended-upgrades..."
echo 'Unattended-Upgrade::Automatic-Reboot "true";' | sudo tee /etc/apt/apt.conf.d/99-hardening-auto-reboot.conf > /dev/null

echo "Installing libpam-pwquality (password quality checking)..."
sudo apt install -y libpam-pwquality

echo "Installation complete."

echo "Configuring basic UFW rules..."
# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH connections (OpenSSH is the service name)
sudo ufw allow OpenSSH
sudo ufw allow 22/tcp # Explicitly allow TCP port 22 as a fallback

# Enable UFW - use --force to avoid interactive prompt in script
sudo ufw --force enable

echo "UFW has been configured with basic rules and enabled."
echo "Remember to further configure services like Fail2Ban and Auditd as needed."
