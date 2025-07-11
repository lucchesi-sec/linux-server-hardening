#!/bin/bash
# Basic script to install Logstash on Debian/Ubuntu.
# For RHEL/CentOS, use yum/dnf commands.

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Prerequisites (Java should already be installed for Elasticsearch)
apt update
apt install -y apt-transport-https # If not already installed

# Add Elasticsearch repository key (if not already added)
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

# Add Elasticsearch repository (if not already added)
# Ensure you are using the same version repo as Elasticsearch/Kibana
echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

# Install Logstash
apt update
apt install -y logstash

# Configuration for Logstash is typically done via pipeline files
# in /etc/logstash/conf.d/
# Example: Create a simple pipeline /etc/logstash/conf.d/beats-input.conf
# input { beats { port => 5044 } }
# output { elasticsearch { hosts => ["localhost:9200"] index => "%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}" } }

# Enable and start Logstash service
systemctl enable logstash.service
systemctl start logstash.service

echo "Logstash installation attempted."
echo "Check service status: systemctl status logstash.service"
echo "Configure pipelines in /etc/logstash/conf.d/"
