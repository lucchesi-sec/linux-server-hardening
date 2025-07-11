#!/bin/bash

# UFW Firewall Module
# Configures Uncomplicated Firewall for network security

# Module metadata
MODULE_NAME="ufw"
MODULE_DESCRIPTION="UFW firewall configuration and management"
MODULE_VERSION="1.0"

# Module configuration
UFW_CONFIG_DIR="/etc/ufw"
UFW_BACKUP_DIR="/etc/ufw/backup.$(date +%Y%m%d-%H%M%S)"

# Execute UFW firewall hardening
ufw_apply() {
    print_info "Starting UFW firewall hardening..."
    
    # Install UFW if not present
    if ! command -v ufw >/dev/null 2>&1; then
        install_ufw
        if [[ $? -ne 0 ]]; then
            print_error "Failed to install UFW"
            return 1
        fi
    fi
    
    # Backup current configuration
    backup_ufw_config
    
    # Configure UFW settings
    configure_ufw_rules
    
    # Enable UFW firewall
    enable_ufw_firewall
    
    # Validate configuration
    if validate_ufw_config; then
        print_success "UFW firewall hardening completed successfully"
        return 0
    else
        print_error "UFW firewall validation failed"
        return 1
    fi
}

# Install UFW if not present
install_ufw() {
    print_info "Installing UFW firewall..."
    
    if [[ "$(get_config dry_run)" == "true" ]]; then
        print_info "DRY RUN: Would install UFW package"
        return 0
    fi
    
    # Detect package manager and install
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y ufw
    elif command -v yum >/dev/null 2>&1; then
        yum install -y ufw
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y ufw
    elif command -v pacman >/dev/null 2>&1; then
        pacman -S --noconfirm ufw
    else
        print_error "Unable to detect package manager for UFW installation"
        return 1
    fi
    
    if command -v ufw >/dev/null 2>&1; then
        print_success "UFW installed successfully"
        return 0
    else
        print_error "UFW installation failed"
        return 1
    fi
}

# Backup UFW configuration
backup_ufw_config() {
    if [[ "$(get_config backup_configs)" != "true" ]]; then
        return 0
    fi
    
    print_verbose "Backing up UFW configuration..."
    
    if [[ "$(get_config dry_run)" == "true" ]]; then
        print_info "DRY RUN: Would backup UFW configuration to $UFW_BACKUP_DIR"
        return 0
    fi
    
    if [[ -d "$UFW_CONFIG_DIR" ]]; then
        mkdir -p "$UFW_BACKUP_DIR"
        cp -r "$UFW_CONFIG_DIR"/* "$UFW_BACKUP_DIR/" 2>/dev/null || true
        print_verbose "UFW configuration backed up to $UFW_BACKUP_DIR"
    fi
}

# Configure UFW rules and policies
configure_ufw_rules() {
    print_verbose "Configuring UFW firewall rules..."
    
    if [[ "$(get_config dry_run)" == "true" ]]; then
        print_info "DRY RUN: Would configure UFW with the following settings:"
        print_info "  - Default incoming policy: deny"
        print_info "  - Default outgoing policy: allow"
        print_info "  - Allow SSH (port 22)"
        print_info "  - Allow HTTP (port 80)"
        print_info "  - Allow HTTPS (port 443)"
        print_info "  - Enable logging"
        return 0
    fi
    
    # Reset UFW to defaults
    ufw --force reset >/dev/null 2>&1
    
    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow essential services
    configure_allowed_ports
    
    # Configure UFW logging
    ufw logging on
    
    print_success "UFW rules configured successfully"
}

# Configure allowed ports from configuration
configure_allowed_ports() {
    local default_ports=("22/tcp" "80/tcp" "443/tcp")
    local config_ports
    
    # Get ports from configuration or use defaults
    config_ports=$(get_config "ufw_allowed_ports" "")
    if [[ -z "$config_ports" ]]; then
        print_verbose "Using default allowed ports"
        for port in "${default_ports[@]}"; do
            ufw allow "$port"
            print_verbose "Allowed port: $port"
        done
    else
        print_verbose "Using configured allowed ports"
        IFS=',' read -ra ports <<< "$config_ports"
        for port in "${ports[@]}"; do
            port=$(echo "$port" | xargs)  # Trim whitespace
            ufw allow "$port"
            print_verbose "Allowed port: $port"
        done
    fi
}

# Enable UFW firewall
enable_ufw_firewall() {
    print_verbose "Enabling UFW firewall..."
    
    if [[ "$(get_config dry_run)" == "true" ]]; then
        print_info "DRY RUN: Would enable UFW firewall"
        return 0
    fi
    
    # Enable UFW with automatic yes
    ufw --force enable
    
    if ufw status | grep -q "Status: active"; then
        print_success "UFW firewall enabled successfully"
        return 0
    else
        print_error "Failed to enable UFW firewall"
        return 1
    fi
}

# Validate UFW configuration
ufw_validate() {
    print_verbose "Validating UFW configuration..."
    
    if [[ "$(get_config dry_run)" == "true" ]]; then
        print_info "DRY RUN: Would validate UFW configuration"
        return 0
    fi
    
    # Check if UFW is active
    if ! ufw status | grep -q "Status: active"; then
        print_error "UFW is not active"
        return 1
    fi
    
    # Check default policies
    local status_output
    status_output=$(ufw status verbose)
    
    if ! echo "$status_output" | grep -q "Default: deny (incoming)"; then
        print_error "Default incoming policy is not set to deny"
        return 1
    fi
    
    if ! echo "$status_output" | grep -q "Default: allow (outgoing)"; then
        print_error "Default outgoing policy is not set to allow"
        return 1
    fi
    
    # Check if SSH port is allowed
    if ! echo "$status_output" | grep -q "22/tcp"; then
        print_warning "SSH port (22/tcp) is not explicitly allowed"
    fi
    
    print_success "UFW configuration validation passed"
    return 0
}

# Show UFW status
show_ufw_status() {
    print_subsection "UFW Firewall Status"
    
    if command -v ufw >/dev/null 2>&1; then
        ufw status verbose
    else
        print_warning "UFW is not installed"
    fi
}

# Get module information
get_ufw_module_info() {
    cat << EOF
Module: $MODULE_NAME
Description: $MODULE_DESCRIPTION
Version: $MODULE_VERSION

This module configures UFW (Uncomplicated Firewall) by:
- Installing UFW if not present
- Setting secure default policies (deny incoming, allow outgoing)
- Configuring essential service ports (SSH, HTTP, HTTPS)
- Enabling firewall logging
- Activating the firewall

Configuration directory: $UFW_CONFIG_DIR
Backup location: $UFW_BACKUP_DIR
EOF
}

# Module help
show_ufw_help() {
    echo "UFW Firewall Module Help"
    echo "========================"
    echo
    get_ufw_module_info
    echo
    echo "Configuration options:"
    echo "  backup_configs: Create backup before changes (default: true)"
    echo "  dry_run: Preview changes without applying (default: false)"
    echo "  ufw_allowed_ports: Comma-separated list of ports to allow (default: 22/tcp,80/tcp,443/tcp)"
    echo
    echo "Examples:"
    echo "  # Allow custom ports"
    echo "  ufw_allowed_ports=22/tcp,8080/tcp,9090/tcp"
    echo
    echo "  # View current status"
    echo "  ufw status verbose"
    echo
}

# Advanced UFW configuration
configure_advanced_ufw() {
    print_info "Configuring advanced UFW settings..."
    
    if [[ "$(get_config dry_run)" == "true" ]]; then
        print_info "DRY RUN: Would configure advanced UFW settings:"
        print_info "  - Rate limiting for SSH"
        print_info "  - IPv6 support"
        print_info "  - Application profiles"
        return 0
    fi
    
    # Enable rate limiting for SSH
    ufw limit ssh/tcp
    
    # Ensure IPv6 is enabled
    sed -i 's/IPV6=no/IPV6=yes/' /etc/default/ufw 2>/dev/null || true
    
    print_success "Advanced UFW configuration applied"
}

# Rollback UFW configuration
rollback_ufw_config() {
    if [[ ! -d "$UFW_BACKUP_DIR" ]]; then
        print_error "No backup found to rollback"
        return 1
    fi
    
    print_info "Rolling back UFW configuration..."
    
    if [[ "$(get_config dry_run)" == "true" ]]; then
        print_info "DRY RUN: Would rollback UFW configuration from $UFW_BACKUP_DIR"
        return 0
    fi
    
    # Disable UFW
    ufw --force disable
    
    # Restore backup
    cp -r "$UFW_BACKUP_DIR"/* "$UFW_CONFIG_DIR/"
    
    # Re-enable UFW
    ufw --force enable
    
    print_success "UFW configuration rolled back successfully"
}

# Export module functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Module is being sourced
    export -f ufw_apply
    export -f ufw_validate
    export -f get_ufw_module_info
    export -f show_ufw_help
    export -f show_ufw_status
    export -f configure_advanced_ufw
    export -f rollback_ufw_config
fi