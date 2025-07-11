#!/usr/bin/env bash

# Compliance & Standards Engine
# Automated compliance framework integration and reporting

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/src/cli/output.sh"

# Global compliance settings
COMPLIANCE_DATA_DIR="$PROJECT_ROOT/data/compliance"
COMPLIANCE_REPORTS_DIR="$PROJECT_ROOT/reports/compliance"
COMPLIANCE_CACHE_DIR="$PROJECT_ROOT/.cache/compliance"

# Supported frameworks
declare -A SUPPORTED_FRAMEWORKS=(
    ["cis_ubuntu_22_04"]="CIS Ubuntu Linux 22.04 LTS Benchmark v1.0.0"
    ["nist_800_53"]="NIST SP 800-53 Rev 5"
    ["pci_dss"]="PCI DSS v4.0"
    ["iso_27001"]="ISO/IEC 27001:2022"
    ["soc2"]="SOC 2 Type II"
    ["hipaa"]="HIPAA Security Rule"
)

# Initialize compliance engine
init_compliance_engine() {
    log_info "Initializing compliance engine..."
    
    # Create required directories
    mkdir -p "$COMPLIANCE_DATA_DIR" "$COMPLIANCE_REPORTS_DIR" "$COMPLIANCE_CACHE_DIR"
    
    # Download/update compliance frameworks
    update_compliance_frameworks
    
    log_success "Compliance engine initialized"
}

# Update compliance frameworks
update_compliance_frameworks() {
    log_info "Updating compliance frameworks..."
    
    for framework in "${!SUPPORTED_FRAMEWORKS[@]}"; do
        download_framework_data "$framework"
    done
}

# Download framework data
download_framework_data() {
    local framework="$1"
    local framework_dir="$COMPLIANCE_DATA_DIR/$framework"
    
    log_info "Downloading framework data: $framework"
    mkdir -p "$framework_dir"
    
    case "$framework" in
        "cis_ubuntu_22_04")
            generate_cis_ubuntu_22_04_data "$framework_dir"
            ;;
        "nist_800_53")
            generate_nist_800_53_data "$framework_dir"
            ;;
        "pci_dss")
            generate_pci_dss_data "$framework_dir"
            ;;
        *)
            log_warning "Framework data generator not implemented: $framework"
            ;;
    esac
}

# Generate CIS Ubuntu 22.04 compliance data
generate_cis_ubuntu_22_04_data() {
    local framework_dir="$1"
    
    cat > "$framework_dir/controls.yaml" << 'EOF'
framework:
  name: "CIS Ubuntu Linux 22.04 LTS Benchmark"
  version: "v1.0.0"
  description: "Center for Internet Security benchmark for Ubuntu 22.04"

sections:
  - id: "1"
    title: "Initial Setup"
    controls:
      - id: "1.1.1.1"
        title: "Ensure mounting of cramfs filesystems is disabled"
        description: "The cramfs filesystem type is a compressed read-only Linux filesystem embedded in small footprint systems"
        level: 1
        automated: true
        check_command: "lsmod | grep cramfs || echo 'not loaded'"
        remediation: "echo 'install cramfs /bin/true' >> /etc/modprobe.d/cramfs.conf"
        
      - id: "1.1.1.2"  
        title: "Ensure mounting of freevxfs filesystems is disabled"
        description: "The freevxfs filesystem type is a free version of the Veritas type filesystem"
        level: 1
        automated: true
        check_command: "lsmod | grep freevxfs || echo 'not loaded'"
        remediation: "echo 'install freevxfs /bin/true' >> /etc/modprobe.d/freevxfs.conf"

  - id: "2"
    title: "Services"
    controls:
      - id: "2.1.1"
        title: "Ensure xinetd is not installed"
        description: "The eXtended InterNET Daemon (xinetd) is an open source super daemon"
        level: 1
        automated: true
        check_command: "dpkg -l | grep xinetd || echo 'not installed'"
        remediation: "apt purge xinetd"
        
  - id: "5"
    title: "Access, Authentication and Authorization"
    controls:
      - id: "5.2.1"
        title: "Ensure permissions on /etc/ssh/sshd_config are configured"
        description: "The /etc/ssh/sshd_config file contains configuration specifications for sshd"
        level: 1
        automated: true
        check_command: "stat -c '%a %U %G' /etc/ssh/sshd_config"
        expected_result: "600 root root"
        remediation: "chown root:root /etc/ssh/sshd_config && chmod og-rwx /etc/ssh/sshd_config"
EOF
}

# Generate NIST 800-53 compliance data
generate_nist_800_53_data() {
    local framework_dir="$1"
    
    cat > "$framework_dir/controls.yaml" << 'EOF'
framework:
  name: "NIST SP 800-53 Rev 5"
  version: "Rev 5"
  description: "Security and Privacy Controls for Information Systems and Organizations"

control_families:
  - id: "AC"
    title: "Access Control"
    controls:
      - id: "AC-2"
        title: "Account Management"
        description: "Manage information system accounts"
        check_commands:
          - "cat /etc/passwd | wc -l"
          - "lastlog"
        baseline: "low,moderate,high"
        
  - id: "AU"
    title: "Audit and Accountability"  
    controls:
      - id: "AU-2"
        title: "Event Logging"
        description: "Identify types of events to be logged"
        check_commands:
          - "systemctl is-active auditd"
          - "auditctl -l"
        baseline: "low,moderate,high"
        
  - id: "SC"
    title: "System and Communications Protection"
    controls:
      - id: "SC-7"
        title: "Boundary Protection"
        description: "Monitor and control communications at external boundaries"
        check_commands:
          - "ufw status"
          - "iptables -L"
        baseline: "low,moderate,high"
EOF
}

# Generate PCI DSS compliance data
generate_pci_dss_data() {
    local framework_dir="$1"
    
    cat > "$framework_dir/controls.yaml" << 'EOF'
framework:
  name: "PCI DSS"
  version: "v4.0"
  description: "Payment Card Industry Data Security Standard"

requirements:
  - id: "1"
    title: "Install and maintain network security controls"
    sub_requirements:
      - id: "1.1.1"
        title: "Processes and mechanisms for installing and maintaining network security controls are defined and understood"
        check_commands:
          - "ufw status verbose"
          
  - id: "2"
    title: "Apply secure configurations to all system components"
    sub_requirements:
      - id: "2.1.1"
        title: "All default passwords are changed before installation of system components on the network"
        check_commands:
          - "grep -v '^#' /etc/shadow | cut -d: -f1,2"
          
  - id: "8"
    title: "Identify users and authenticate access to system components"
    sub_requirements:
      - id: "8.2.1"
        title: "Strong cryptography is used to render all authentication factors unreadable during transmission and storage"
        check_commands:
          - "grep '^PasswordAuthentication' /etc/ssh/sshd_config"
          - "grep '^PubkeyAuthentication' /etc/ssh/sshd_config"
EOF
}

# Run compliance scan
run_compliance_scan() {
    local framework="$1"
    local profile="${2:-default}"
    local output_format="${3:-json}"
    
    log_info "Running compliance scan: $framework ($profile)"
    
    if [[ ! -f "$COMPLIANCE_DATA_DIR/$framework/controls.yaml" ]]; then
        log_error "Framework data not found: $framework"
        return 1
    fi
    
    local report_file="$COMPLIANCE_REPORTS_DIR/${framework}_$(date +%Y%m%d_%H%M%S).${output_format}"
    local temp_results="/tmp/compliance_scan_$$"
    
    # Initialize results
    cat > "$temp_results" << EOF
{
  "framework": "$framework",
  "profile": "$profile",
  "scan_time": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "results": []
}
EOF
    
    # Execute compliance checks based on framework
    case "$framework" in
        "cis_ubuntu_22_04")
            execute_cis_checks "$temp_results"
            ;;
        "nist_800_53")
            execute_nist_checks "$temp_results"
            ;;
        "pci_dss")
            execute_pci_checks "$temp_results"
            ;;
        *)
            log_error "Compliance scanner not implemented: $framework"
            return 1
            ;;
    esac
    
    # Generate final report
    generate_compliance_report "$temp_results" "$report_file" "$output_format"
    
    # Cleanup
    rm -f "$temp_results"
    
    log_success "Compliance scan completed: $report_file"
}

# Execute CIS compliance checks
execute_cis_checks() {
    local results_file="$1"
    
    # Sample CIS checks
    local checks=(
        "1.1.1.1:lsmod | grep cramfs:not loaded"
        "5.2.1:stat -c '%a %U %G' /etc/ssh/sshd_config:600 root root"
    )
    
    for check in "${checks[@]}"; do
        IFS=':' read -r control_id command expected <<< "$check"
        
        local result
        result=$(eval "$command" 2>/dev/null || echo "FAILED")
        
        local status="FAIL"
        if [[ "$result" == "$expected" ]] || [[ "$result" == *"$expected"* ]]; then
            status="PASS"
        fi
        
        # Append to results (simplified JSON)
        log_info "Control $control_id: $status"
    done
}

# Execute NIST 800-53 checks
execute_nist_checks() {
    local results_file="$1"
    
    log_info "Executing NIST 800-53 compliance checks..."
    
    # AC-2: Account Management
    local user_count
    user_count=$(cat /etc/passwd | wc -l)
    log_info "AC-2: User accounts found: $user_count"
    
    # AU-2: Event Logging  
    local auditd_status
    auditd_status=$(systemctl is-active auditd 2>/dev/null || echo "inactive")
    log_info "AU-2: Auditd status: $auditd_status"
    
    # SC-7: Boundary Protection
    local firewall_status
    firewall_status=$(ufw status 2>/dev/null | head -1 || echo "inactive")
    log_info "SC-7: Firewall status: $firewall_status"
}

# Execute PCI DSS checks
execute_pci_checks() {
    local results_file="$1"
    
    log_info "Executing PCI DSS compliance checks..."
    
    # Requirement 1: Network security controls
    local ufw_status
    ufw_status=$(ufw status verbose 2>/dev/null || echo "Status: inactive")
    log_info "Req 1.1.1: UFW status: $ufw_status"
    
    # Requirement 8: Authentication
    local ssh_password_auth
    ssh_password_auth=$(grep '^PasswordAuthentication' /etc/ssh/sshd_config 2>/dev/null || echo "not configured")
    log_info "Req 8.2.1: SSH password auth: $ssh_password_auth"
}

# Generate compliance report
generate_compliance_report() {
    local results_file="$1"
    local output_file="$2" 
    local format="$3"
    
    case "$format" in
        "json")
            cp "$results_file" "$output_file"
            ;;
        "html")
            generate_html_report "$results_file" "$output_file"
            ;;
        "csv")
            generate_csv_report "$results_file" "$output_file"
            ;;
        *)
            log_error "Unsupported report format: $format"
            return 1
            ;;
    esac
}

# Generate HTML compliance report
generate_html_report() {
    local results_file="$1"
    local output_file="$2"
    
    cat > "$output_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Compliance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f4f4f4; padding: 15px; border-radius: 5px; }
        .pass { color: green; font-weight: bold; }
        .fail { color: red; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Security Compliance Report</h1>
        <p>Generated: DATE_PLACEHOLDER</p>
    </div>
    <table>
        <tr><th>Control ID</th><th>Description</th><th>Status</th><th>Details</th></tr>
        <!-- Results will be inserted here -->
    </table>
</body>
</html>
EOF
    
    # Replace placeholder with actual date
    sed -i "s/DATE_PLACEHOLDER/$(date)/" "$output_file"
}

# List available frameworks
list_frameworks() {
    log_info "Available compliance frameworks:"
    echo
    
    for framework in "${!SUPPORTED_FRAMEWORKS[@]}"; do
        printf "  %-20s %s\n" "$framework" "${SUPPORTED_FRAMEWORKS[$framework]}"
    done
}

# Show compliance status
show_compliance_status() {
    local framework="${1:-all}"
    
    if [[ "$framework" == "all" ]]; then
        log_info "Compliance status for all frameworks:"
        for fw in "${!SUPPORTED_FRAMEWORKS[@]}"; do
            show_framework_status "$fw"
        done
    else
        show_framework_status "$framework"
    fi
}

# Show framework status
show_framework_status() {
    local framework="$1"
    
    if [[ ! -f "$COMPLIANCE_DATA_DIR/$framework/controls.yaml" ]]; then
        printf "  %-20s %s\n" "$framework" "Not configured"
        return
    fi
    
    local latest_report
    latest_report=$(find "$COMPLIANCE_REPORTS_DIR" -name "${framework}_*.json" -type f | sort | tail -1)
    
    if [[ -n "$latest_report" ]]; then
        local scan_date
        scan_date=$(basename "$latest_report" | sed 's/.*_\([0-9]\{8\}_[0-9]\{6\}\).*/\1/')
        printf "  %-20s %s\n" "$framework" "Last scan: $scan_date"
    else
        printf "  %-20s %s\n" "$framework" "Never scanned"
    fi
}

# Main function
main() {
    case "${1:-help}" in
        "init")
            init_compliance_engine
            ;;
        "scan")
            local framework="${2:-cis_ubuntu_22_04}"
            local profile="${3:-default}"
            local format="${4:-json}"
            run_compliance_scan "$framework" "$profile" "$format"
            ;;
        "list")
            list_frameworks
            ;;
        "status")
            show_compliance_status "${2:-all}"
            ;;
        "update")
            update_compliance_frameworks
            ;;
        "help"|*)
            cat << EOF
Compliance Engine Usage:
  init              Initialize compliance engine
  scan FRAMEWORK    Run compliance scan (default: cis_ubuntu_22_04)
  list              List available frameworks
  status [FW]       Show compliance status
  update            Update framework data
  help              Show this help

Available frameworks: ${!SUPPORTED_FRAMEWORKS[*]}
EOF
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi