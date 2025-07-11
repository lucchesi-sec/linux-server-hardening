#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.
# Basic script to install Elasticsearch on Debian/Ubuntu.
# For RHEL/CentOS, use yum/dnf commands.

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Prerequisites
apt update
apt install -y apt-transport-https openjdk-11-jre # Or a compatible Java version

# Add Elasticsearch repository key (using modern GPG key management)
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg

# Add Elasticsearch repository with signed-by option
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

# Install Elasticsearch
apt update
apt install -y elasticsearch

# Configure Elasticsearch (basic example - listen on localhost)
# Modify /etc/elasticsearch/elasticsearch.yml as needed, e.g., for network.host, cluster name
# Example: sed -i 's/#network.host: 192.168.0.1/network.host: localhost/' /etc/elasticsearch/elasticsearch.yml

# Enable and start Elasticsearch service
systemctl daemon-reload
systemctl enable elasticsearch.service
systemctl start elasticsearch.service

echo "Elasticsearch installation attempted."
echo "Check service status: systemctl status elasticsearch.service"
echo "Default port: 9200"
