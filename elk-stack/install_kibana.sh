#!/bin/bash
# Basic script to install Kibana on Debian/Ubuntu.
# For RHEL/CentOS, use yum/dnf commands.

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Prerequisites
apt update
apt install -y apt-transport-https # If not already installed

# Add Elasticsearch repository key (if not already added)
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

# Add Elasticsearch repository (if not already added)
# Ensure you are using the same version repo as Elasticsearch/Logstash
echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

# Install Kibana
apt update
apt install -y kibana

# Configure Kibana (basic example - listen on localhost)
# Modify /etc/kibana/kibana.yml as needed, e.g., for server.host, elasticsearch.hosts
# Example:
# sed -i 's/#server.host: "localhost"/server.host: "localhost"/' /etc/kibana/kibana.yml
# sed -i 's/#elasticsearch.hosts: ["http://localhost:9200"]/elasticsearch.hosts: ["http://localhost:9200"]/' /etc/kibana/kibana.yml

# Enable and start Kibana service
systemctl daemon-reload
systemctl enable kibana.service
systemctl start kibana.service

echo "Kibana installation attempted."
echo "Check service status: systemctl status kibana.service"
echo "Access Kibana via http://<your-server-ip>:5601"
