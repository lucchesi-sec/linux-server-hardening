#!/usr/bin/env bash

# AIDE File Integrity Monitoring Module
# Advanced Intrusion Detection Environment for file integrity monitoring

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$PROJECT_ROOT/src/cli/output.sh"
source "$PROJECT_ROOT/src/core/distro_detection.sh"

# Module metadata
MODULE_NAME="aide"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="AIDE File Integrity Monitoring"

# AIDE configuration
AIDE_CONFIG="/etc/aide/aide.conf"
AIDE_DB="/var/lib/aide/aide.db"
AIDE_NEW_DB="/var/lib/aide/aide.db.new"
AIDE_REPORTS_DIR="/var/log/aide"

# Get module information
get_aide_module_info() {
    cat << EOF
{
  "name": "$MODULE_NAME",
  "version": "$MODULE_VERSION",
  "description": "$MODULE_DESCRIPTION", 
  "dependencies": ["aide"],
  "config_files": [
    "/etc/aide/aide.conf",
    "/etc/cron.d/aide"
  ],
  "services": [],
  "supports_dry_run": true,
  "supports_validation": true
}
EOF
}

# Show module help
show_aide_help() {
    cat << EOF
AIDE File Integrity Monitoring Module Help

DESCRIPTION:
    Configures AIDE (Advanced Intrusion Detection Environment) for file
    integrity monitoring. AIDE creates a database of files and monitors
    changes to detect unauthorized modifications.

FEATURES:
    - Install and configure AIDE
    - Initialize file integrity database
    - Monitor critical system files and directories
    - Automated daily integrity checks
    - Email notification of changes
    - Custom monitoring rules

CONFIGURATION:
    modules:
      aide:
        enabled: true
        init_db: true
        daily_check: true
        email_reports: true
        monitor_paths:
          - /etc
          - /bin
          - /sbin
          - /usr/bin
          - /usr/sbin
        exclude_paths:
          - /var/log
          - /tmp
          - /proc
          - /sys

COMMANDS:
    init        Initialize AIDE database
    check       Run integrity check
    update      Update database after changes
    status      Show AIDE status
    report      Generate integrity report
EOF
}

# Validate AIDE configuration
validate_aide_config() {
    local config_file="$1"
    
    log_info "Validating AIDE configuration..."
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi
    
    # Parse YAML configuration (simplified)
    local enabled
    enabled=$(grep -E "^\s*enabled:" "$config_file" | awk '{print $2}' || echo "true")
    
    if [[ "$enabled" != "true" && "$enabled" != "false" ]]; then
        log_error "Invalid 'enabled' value in configuration"
        return 1
    fi
    
    log_success "AIDE configuration validation passed"
    return 0
}

# Install AIDE
install_aide() {
    log_info "Installing AIDE..."
    
    local distro
    distro=$(detect_distribution)
    
    case "$distro" in
        "ubuntu"|"debian")
            apt-get update
            apt-get install -y aide aide-common
            ;;
        "rhel"|"centos"|"fedora")
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y aide
            else
                yum install -y aide
            fi
            ;;
        *)
            log_error "Unsupported distribution for AIDE: $distro"
            return 1
            ;;
    esac
    
    log_success "AIDE installed successfully"
}

# Configure AIDE
configure_aide() {
    log_info "Configuring AIDE..."
    
    # Create AIDE configuration directory
    mkdir -p "$(dirname "$AIDE_CONFIG")"
    mkdir -p "$AIDE_REPORTS_DIR"
    
    # Create AIDE configuration
    cat > "$AIDE_CONFIG" << 'EOF'
# AIDE Configuration File
# Advanced Intrusion Detection Environment

# Database and report locations
database=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new
gzip_dbout=yes

# Report settings
verbose=5
report_url=file:/var/log/aide/aide.log
report_url=stdout

# Monitoring rules
# p = permissions, i = inode, n = number of links, u = user, g = group
# s = size, b = block count, m = mtime, a = atime, c = ctime, S = check for growing size
# md5|sha1|sha256|sha512 = checksum algorithms

# Define custom rules
FIPSR = p+i+n+u+g+s+m+c+md5+sha256
NORMAL = FIPSR+a
DIR = p+i+n+u+g+a
LOGDIR = p+i+n+u+g
GROWING = p+i+n+u+g+a+S

# Critical system directories (read-only)
/boot NORMAL
/bin NORMAL
/sbin NORMAL
/usr/bin NORMAL
/usr/sbin NORMAL
/usr/local/bin NORMAL
/usr/local/sbin NORMAL

# System configuration
/etc NORMAL

# Libraries
/lib NORMAL
/lib64 NORMAL
/usr/lib NORMAL
/usr/lib64 NORMAL

# Important files
/etc/passwd FIPSR
/etc/shadow FIPSR
/etc/group FIPSR
/etc/gshadow FIPSR
/etc/sudoers FIPSR
/etc/ssh/sshd_config FIPSR
/etc/hosts FIPSR
/etc/resolv.conf FIPSR

# Kernel and modules
/lib/modules NORMAL

# Root directory structure
/root NORMAL

# Log directories (monitor structure but allow growth)
/var/log LOGDIR

# Exclude volatile directories
!/var/log/.*
!/tmp/.*
!/proc/.*
!/sys/.*
!/dev/.*
!/run/.*
!/var/run/.*
!/var/cache/.*
!/var/tmp/.*
!/home/.*/\.cache/.*
!/home/.*/\.mozilla/.*
!/home/.*/\.local/share/Trash/.*

# User home directories (basic monitoring)
/home DIR

# Package manager files
/var/lib/dpkg NORMAL
/var/lib/rpm NORMAL

# Cron directories
/etc/cron.d NORMAL
/etc/cron.daily NORMAL
/etc/cron.hourly NORMAL
/etc/cron.monthly NORMAL
/etc/cron.weekly NORMAL
/var/spool/cron NORMAL

# Service configurations
/etc/systemd NORMAL
/etc/init.d NORMAL

# Network configuration
/etc/network NORMAL
/etc/netplan NORMAL

# Security configurations
/etc/security NORMAL
/etc/pam.d NORMAL
/etc/apparmor.d NORMAL
/etc/selinux NORMAL

# Package configurations
/etc/apt NORMAL
/etc/yum.repos.d NORMAL

# Mail system
/etc/postfix NORMAL
/etc/mail NORMAL

# Web server configurations
/etc/apache2 NORMAL
/etc/nginx NORMAL
/etc/httpd NORMAL

# Database configurations
/etc/mysql NORMAL
/etc/postgresql NORMAL

# Additional application directories
/opt NORMAL
EOF
    
    log_success "AIDE configuration created"
}

# Initialize AIDE database
initialize_aide_database() {
    log_info "Initializing AIDE database..."
    
    # Remove existing database if present
    if [[ -f "$AIDE_DB" ]]; then
        log_info "Removing existing AIDE database"
        rm -f "$AIDE_DB"
    fi
    
    # Initialize new database
    log_info "Creating initial AIDE database (this may take several minutes)..."
    aide --init --config="$AIDE_CONFIG"
    
    # Move new database to active location
    if [[ -f "$AIDE_NEW_DB" ]]; then
        mv "$AIDE_NEW_DB" "$AIDE_DB"
        log_success "AIDE database initialized successfully"
    else
        log_error "Failed to create AIDE database"
        return 1
    fi
}

# Run AIDE integrity check
run_aide_check() {
    local report_file="${1:-$AIDE_REPORTS_DIR/aide-check-$(date +%Y%m%d_%H%M%S).txt}"
    
    log_info "Running AIDE integrity check..."
    
    # Ensure database exists
    if [[ ! -f "$AIDE_DB" ]]; then
        log_error "AIDE database not found. Please initialize first."
        return 1
    fi
    
    # Create reports directory
    mkdir -p "$(dirname "$report_file")"
    
    # Run check and capture results
    local check_result=0
    aide --check --config="$AIDE_CONFIG" > "$report_file" 2>&1 || check_result=$?
    
    # Parse results
    case $check_result in
        0)
            log_success "AIDE check completed: No changes detected"
            ;;
        1)
            log_warning "AIDE check completed: New files detected"
            show_aide_summary "$report_file"
            ;;
        2)
            log_warning "AIDE check completed: Removed files detected"
            show_aide_summary "$report_file"
            ;;
        3)
            log_warning "AIDE check completed: Changed files detected"
            show_aide_summary "$report_file"
            ;;
        4)
            log_warning "AIDE check completed: New and removed files detected"
            show_aide_summary "$report_file"
            ;;
        5)
            log_warning "AIDE check completed: New and changed files detected"
            show_aide_summary "$report_file"
            ;;
        6)
            log_warning "AIDE check completed: Removed and changed files detected"
            show_aide_summary "$report_file"
            ;;
        7)
            log_warning "AIDE check completed: All types of changes detected"
            show_aide_summary "$report_file"
            ;;
        *)
            log_error "AIDE check failed with exit code: $check_result"
            return 1
            ;;
    esac
    
    log_info "Full report saved to: $report_file"
    return $check_result
}

# Show AIDE summary
show_aide_summary() {
    local report_file="$1"
    
    if [[ ! -f "$report_file" ]]; then
        log_error "Report file not found: $report_file"
        return 1
    fi
    
    echo
    log_info "AIDE Check Summary:"
    echo "==================="
    
    # Extract summary information
    local added_files
    added_files=$(grep -c "^f+++++++++++" "$report_file" 2>/dev/null || echo "0")
    
    local removed_files  
    removed_files=$(grep -c "^f----------" "$report_file" 2>/dev/null || echo "0")
    
    local changed_files
    changed_files=$(grep -c "^f\.\.\.\.\.\.\.\.\.\." "$report_file" 2>/dev/null || echo "0")
    
    echo "Added files:    $added_files"
    echo "Removed files:  $removed_files"
    echo "Changed files:  $changed_files"
    
    # Show first few changes
    echo
    echo "Sample changes (first 10):"
    grep -E "^(f\+|f-|f\.)" "$report_file" | head -10 || echo "No detailed changes found"
}

# Update AIDE database
update_aide_database() {
    log_info "Updating AIDE database..."
    
    # Create new database
    aide --update --config="$AIDE_CONFIG"
    
    # Replace old database with new one
    if [[ -f "$AIDE_NEW_DB" ]]; then
        mv "$AIDE_NEW_DB" "$AIDE_DB"
        log_success "AIDE database updated successfully"
    else
        log_error "Failed to update AIDE database"
        return 1
    fi
}

# Setup AIDE cron job
setup_aide_cron() {
    log_info "Setting up AIDE cron job..."
    
    # Create cron script
    local cron_script="/usr/local/bin/aide-check.sh"
    
    cat > "$cron_script" << 'EOF'
#!/bin/bash
# AIDE Daily Check Script

AIDE_CONFIG="/etc/aide/aide.conf"
AIDE_REPORTS_DIR="/var/log/aide"
ADMIN_EMAIL="root@localhost"

# Create reports directory
mkdir -p "$AIDE_REPORTS_DIR"

# Run AIDE check
REPORT_FILE="$AIDE_REPORTS_DIR/aide-daily-$(date +%Y%m%d).txt"
aide --check --config="$AIDE_CONFIG" > "$REPORT_FILE" 2>&1
RESULT=$?

# Check if changes detected
if [[ $RESULT -ne 0 ]]; then
    # Send email notification
    if command -v mail >/dev/null 2>&1; then
        mail -s "AIDE Alert: File Integrity Changes Detected on $(hostname)" "$ADMIN_EMAIL" < "$REPORT_FILE"
    fi
    
    # Log to syslog
    logger -t aide "File integrity changes detected. See $REPORT_FILE"
fi

# Cleanup old reports (keep 30 days)
find "$AIDE_REPORTS_DIR" -name "aide-daily-*.txt" -mtime +30 -delete

exit $RESULT
EOF
    
    chmod +x "$cron_script"
    
    # Create cron job
    cat > "/etc/cron.d/aide" << EOF
# AIDE Daily Integrity Check
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root

# Run daily at 2:30 AM
30 2 * * * root $cron_script
EOF
    
    log_success "AIDE cron job configured"
}

# Show AIDE status
show_aide_status() {
    log_info "AIDE Status Report"
    echo "=================="
    
    # Check if AIDE is installed
    if ! command -v aide >/dev/null 2>&1; then
        echo "AIDE: Not installed"
        return 1
    fi
    
    echo "AIDE: Installed"
    
    # Check database status
    if [[ -f "$AIDE_DB" ]]; then
        local db_size
        db_size=$(du -h "$AIDE_DB" | cut -f1)
        local db_date
        db_date=$(stat -c '%y' "$AIDE_DB" | cut -d' ' -f1)
        echo "Database: $db_size (created: $db_date)"
    else
        echo "Database: Not initialized"
    fi
    
    # Check configuration
    if [[ -f "$AIDE_CONFIG" ]]; then
        echo "Configuration: Present"
    else
        echo "Configuration: Missing"
    fi
    
    # Check cron job
    if [[ -f "/etc/cron.d/aide" ]]; then
        echo "Scheduled checks: Enabled"
    else
        echo "Scheduled checks: Disabled"
    fi
    
    # Show recent reports
    echo
    echo "Recent Reports:"
    find "$AIDE_REPORTS_DIR" -name "*.txt" -type f -mtime -7 2>/dev/null | \
    sort -r | head -5 | while read -r report; do
        local report_date
        report_date=$(stat -c '%y' "$report" | cut -d' ' -f1)
        echo "  $(basename "$report") ($report_date)"
    done || echo "  No recent reports found"
}

# Generate AIDE report
generate_aide_report() {
    local format="${1:-text}"
    local output_file="${2:-$AIDE_REPORTS_DIR/aide-report-$(date +%Y%m%d_%H%M%S).$format}"
    
    log_info "Generating AIDE report..."
    
    case "$format" in
        "text")
            generate_text_report "$output_file"
            ;;
        "html")
            generate_html_report "$output_file"
            ;;
        *)
            log_error "Unsupported report format: $format"
            return 1
            ;;
    esac
    
    log_success "Report generated: $output_file"
}

# Generate text report
generate_text_report() {
    local output_file="$1"
    
    cat > "$output_file" << EOF
AIDE File Integrity Report
Generated: $(date)
Hostname: $(hostname)

Database Information:
$(show_aide_status)

Latest Check Results:
EOF
    
    # Add latest check results
    local latest_report
    latest_report=$(find "$AIDE_REPORTS_DIR" -name "*.txt" -type f | sort -r | head -1)
    
    if [[ -n "$latest_report" ]]; then
        echo "==================" >> "$output_file"
        cat "$latest_report" >> "$output_file"
    else
        echo "No check results available" >> "$output_file"
    fi
}

# Generate HTML report
generate_html_report() {
    local output_file="$1"
    
    cat > "$output_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>AIDE File Integrity Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f4f4f4; padding: 15px; border-radius: 5px; }
        .status { margin: 20px 0; }
        .changes { background: #fff3cd; border: 1px solid #ffeaa7; padding: 10px; }
        pre { background: #f8f9fa; padding: 10px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="header">
        <h1>AIDE File Integrity Report</h1>
        <p>Generated: DATE_PLACEHOLDER</p>
        <p>Hostname: HOSTNAME_PLACEHOLDER</p>
    </div>
    
    <div class="status">
        <h2>System Status</h2>
        <pre>STATUS_PLACEHOLDER</pre>
    </div>
</body>
</html>
EOF
    
    # Replace placeholders
    sed -i "s/DATE_PLACEHOLDER/$(date)/" "$output_file"
    sed -i "s/HOSTNAME_PLACEHOLDER/$(hostname)/" "$output_file"
}

# Main AIDE hardening execution
execute_aide_hardening() {
    local config_file="${1:-$PROJECT_ROOT/configs/default.yaml}"
    local dry_run="${2:-false}"
    
    log_info "Starting AIDE hardening..."
    
    # Validate configuration
    if ! validate_aide_config "$config_file"; then
        return 1
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY RUN] Would perform AIDE hardening"
        log_info "[DRY RUN] Would install AIDE"
        log_info "[DRY RUN] Would configure AIDE"
        log_info "[DRY RUN] Would initialize database"
        log_info "[DRY RUN] Would setup cron job"
        return 0
    fi
    
    # Install AIDE
    install_aide
    
    # Configure AIDE
    configure_aide
    
    # Initialize database
    initialize_aide_database
    
    # Setup cron job
    setup_aide_cron
    
    log_success "AIDE hardening completed"
    
    # Show status
    show_aide_status
}

# Command line interface
main() {
    case "${1:-help}" in
        "execute")
            execute_aide_hardening "${2:-}" "${3:-false}"
            ;;
        "init")
            initialize_aide_database
            ;;
        "check")
            run_aide_check "${2:-}"
            ;;
        "update")
            update_aide_database
            ;;
        "status")
            show_aide_status
            ;;
        "report")
            generate_aide_report "${2:-text}" "${3:-}"
            ;;
        "info")
            get_aide_module_info
            ;;
        "validate")
            validate_aide_config "${2:-$PROJECT_ROOT/configs/default.yaml}"
            ;;
        "help"|*)
            show_aide_help
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi