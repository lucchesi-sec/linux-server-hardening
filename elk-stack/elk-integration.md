# Integrating Hardened Server with ELK Stack

This guide provides basic steps and considerations for integrating your hardened Linux server with an Elasticsearch, Logstash, and Kibana (ELK) stack for centralized logging and monitoring.

## Overview

The ELK stack is a powerful combination for collecting, parsing, storing, and visualizing log data. Integrating logs from your hardened server (like `auditd`, `sshd`, `fail2ban`, system logs) into ELK allows for:

*   **Centralized Log Management:** Store logs from multiple servers in one place.
*   **Security Monitoring:** Analyze logs for suspicious activities, failed logins, policy violations, etc.
*   **Troubleshooting:** Quickly search and filter logs to diagnose issues.
*   **Visualization:** Create dashboards in Kibana to monitor key metrics and events.

## Installation (Optional - If hosting ELK locally)

If you intend to run the ELK stack on the same server you are hardening (generally not recommended for production environments due to resource contention and security implications), you can use the provided scripts:

1.  **Prerequisites:** Ensure you have `wget`, `apt-transport-https`, and a compatible Java Development Kit (JDK) installed (e.g., `openjdk-11-jre`).
2.  **Run Installation Scripts:** Execute the scripts in this directory (as root):
    ```bash
    sudo bash install_elasticsearch.sh
    sudo bash install_logstash.sh
    sudo bash install_kibana.sh
    ```
3.  **Configuration:**
    *   Review and modify configuration files (`/etc/elasticsearch/elasticsearch.yml`, `/etc/kibana/kibana.yml`) according to your needs (e.g., network binding, cluster settings).
    *   Configure Logstash pipelines (`/etc/logstash/conf.d/`) to process incoming logs.
    *   Ensure firewall rules allow necessary traffic (e.g., port 5601 for Kibana, 9200 for Elasticsearch, 5044 for Beats input if used).

**Note:** Running ELK requires significant resources (CPU, RAM, disk space). For production, use dedicated servers for your ELK cluster.

## Log Forwarding

To send logs from your hardened server to an ELK stack (whether local or remote), you need a log shipper.

### Option 1: Filebeat (Recommended for most cases)

Filebeat is a lightweight log shipper from Elastic. It monitors specified log files or locations, forwards log events to Logstash or directly to Elasticsearch, and is generally preferred over installing the full Logstash on every client server.

1.  **Install Filebeat:** Follow the official Elastic documentation for installing Filebeat on your Linux distribution.
    ```bash
    # Example for Debian/Ubuntu (ensure repo is added as in other scripts)
    sudo apt update
    sudo apt install filebeat
    ```
2.  **Configure Filebeat:** Edit `/etc/filebeat/filebeat.yml`.
    *   **Enable Modules:** Filebeat comes with modules for common log types (system, auditd, nginx, etc.). Enable the ones you need:
        ```bash
        sudo filebeat modules enable system auditd # Add other modules as needed
        ```
        This often automatically configures inputs and points to standard log locations.
    *   **Configure Inputs (if modules aren't sufficient):** Manually specify log paths if needed under the `filebeat.inputs` section.
        ```yaml
        filebeat.inputs:
        - type: log
          enabled: true
          paths:
            - /var/log/syslog
            - /var/log/auth.log
            - /var/log/fail2ban.log
            # Add other relevant hardened service logs
          # multiline.pattern: '^[[:space:]]' # Example for multi-line logs
          # multiline.negate: false
          # multiline.match: after
        ```
    *   **Configure Output:** Specify where to send the logs. Usually Logstash or Elasticsearch.
        ```yaml
        # Output to Logstash
        output.logstash:
          hosts: ["your-logstash-server:5044"]
          # ssl.enabled: true # Recommended for production
          # ssl.certificate_authorities: ["/etc/pki/tls/certs/logstash-ca.crt"]

        # OR Output directly to Elasticsearch
        # output.elasticsearch:
        #   hosts: ["your-elasticsearch-server:9200"]
        #   username: "elastic" # Use appropriate credentials
        #   password: "your_password"
        #   ssl.enabled: true # Recommended for production
        #   ssl.certificate_authorities: ["/etc/pki/tls/certs/elasticsearch-ca.crt"]
        ```
    *   **Load Kibana Dashboards (Optional):** If Filebeat modules were enabled and you're outputting to Elasticsearch, load associated Kibana dashboards:
        ```bash
        sudo filebeat setup --dashboards
        ```
3.  **Start Filebeat:**
    ```bash
    sudo systemctl enable filebeat
    sudo systemctl start filebeat
    ```

### Option 2: Logstash (As a shipper - Less common)

While Logstash is powerful for *processing* logs, installing it on every server just for shipping is resource-intensive. It's usually better suited for running on dedicated nodes or alongside Elasticsearch.

If you must use Logstash as a shipper:

1.  **Install Logstash:** Use `install_logstash.sh` or follow official docs.
2.  **Configure Pipeline:** Create a pipeline configuration in `/etc/logstash/conf.d/`.
    *   Use input plugins like `file` or `syslog` to read local logs.
    *   Use output plugins like `elasticsearch` or `lumberjack` (for sending to another Logstash instance) to forward the logs.

## Important Considerations

*   **Security:** Secure your ELK stack (TLS encryption, authentication, role-based access control). Secure the communication between Filebeat/Logstash and the ELK cluster.
*   **Resource Management:** Monitor resource usage on both the hardened server (if running Filebeat/Logstash) and the ELK cluster.
*   **Log Rotation:** Ensure log rotation is configured on the hardened server to prevent filling up disk space. Filebeat handles rotated files correctly.
*   **Firewall Rules:** Adjust firewall rules (`ufw`, `firewalld`) on the hardened server and the ELK servers to allow necessary traffic (e.g., port 5044 for Beats input to Logstash, 9200/9300 for Elasticsearch, 5601 for Kibana).
*   **Auditd:** The `auditd` logs are particularly valuable but can be verbose. Use Filebeat's `auditd` module or configure `auditd` rules carefully (`/etc/audit/rules.d/`) to log relevant events without excessive noise.
*   **Parsing:** Ensure logs are correctly parsed either by Filebeat modules, Logstash filters (grok, dissect, date, etc.), or Elasticsearch ingest pipelines.

## Accessing Kibana

Once logs are flowing into Elasticsearch, you can access Kibana via your browser (typically `http://your-kibana-server:5601`). Use the Discover tab to explore logs and the Dashboard tab to view visualizations.
