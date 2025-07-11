#!/bin/bash

# SSH Hardening Module
# Secures SSH daemon configuration

# Module metadata
MODULE_NAME="ssh"
MODULE_DESCRIPTION="SSH daemon security hardening"
MODULE_VERSION="1.0"

# Module configuration
SSH_CONFIG_FILE="/etc/ssh/sshd_config"
SSH_BACKUP_FILE="/etc/ssh/sshd_config.backup.$(date +%Y%m%d-%H%M%S)"

# Execute SSH hardening
ssh_apply() {
    print_info "Starting SSH hardening..."
    
    # Check if SSH is installed
    if ! command -v sshd >/dev/null 2>&1; then
        print_warning "SSH daemon not found, skipping SSH hardening"
        return 2
    fi
    
    # Backup current configuration
    if [[ -f "$SSH_CONFIG_FILE" ]]; then
        if [[ "$(get_config backup_configs)" == "true" ]]; then
            print_verbose "Backing up SSH configuration to $SSH_BACKUP_FILE"
            cp "$SSH_CONFIG_FILE" "$SSH_BACKUP_FILE"
        fi
    else
        print_error "SSH configuration file not found: $SSH_CONFIG_FILE"
        return 1
    fi
    
    # Apply SSH hardening settings
    apply_ssh_settings
    
    # Validate configuration
    if validate_ssh_config; then
        print_success "SSH hardening completed successfully"
        
        # Restart SSH service if not in dry run mode
        if [[ "$(get_config dry_run)" != "true" ]]; then
            restart_ssh_service
        else
            print_info "DRY RUN: Would restart SSH service"
        fi
        
        return 0
    else
        print_error "SSH configuration validation failed"
        return 1
    fi
}

# Apply SSH security settings
apply_ssh_settings() {
    print_verbose "Applying SSH security settings..."
    
    local temp_config="/tmp/sshd_config.tmp"
    
    if [[ "$(get_config dry_run)" == "true" ]]; then
        print_info "DRY RUN: Would apply SSH hardening settings:"
        print_info "  - Disable root login"
        print_info "  - Disable password authentication"
        print_info "  - Set Protocol 2"
        print_info "  - Disable X11 forwarding"
        print_info "  - Set login grace time"
        return 0
    fi
    
    # Create temporary config file
    cp "$SSH_CONFIG_FILE" "$temp_config"
    
    # Apply hardening settings
    update_ssh_setting "$temp_config" "PermitRootLogin" "no"
    update_ssh_setting "$temp_config" "PasswordAuthentication" "no"
    update_ssh_setting "$temp_config" "Protocol" "2"
    update_ssh_setting "$temp_config" "X11Forwarding" "no"
    update_ssh_setting "$temp_config" "LoginGraceTime" "60"
    update_ssh_setting "$temp_config" "MaxAuthTries" "3"
    update_ssh_setting "$temp_config" "ClientAliveInterval" "300"
    update_ssh_setting "$temp_config" "ClientAliveCountMax" "2"
    
    # Move temporary config to final location
    mv "$temp_config" "$SSH_CONFIG_FILE"
    
    print_success "SSH configuration updated"
}

# Update SSH configuration setting
update_ssh_setting() {
    local config_file="$1"
    local setting="$2"
    local value="$3"
    
    # Remove existing setting (commented or uncommented)
    sed -i.bak "/^#*${setting}/d" "$config_file"
    
    # Add new setting
    echo "${setting} ${value}" >> "$config_file"
    
    print_verbose "Set ${setting} = ${value}"
}

# Validate SSH configuration
validate_ssh_config() {
    print_verbose "Validating SSH configuration..."
    
    if [[ "$(get_config dry_run)" == "true" ]]; then
        print_info "DRY RUN: Would validate SSH configuration"
        return 0
    fi
    
    # Test SSH configuration syntax
    if sshd -t 2>/dev/null; then
        print_verbose "SSH configuration syntax is valid"
        return 0
    else
        print_error "SSH configuration syntax error"
        return 1
    fi
}

# Restart SSH service
restart_ssh_service() {
    print_verbose "Restarting SSH service..."
    
    # Try different service names
    local ssh_services=("ssh" "sshd")
    local restarted=false
    
    for service in "${ssh_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            print_verbose "Restarting $service service..."
            if systemctl restart "$service" 2>/dev/null; then
                print_success "SSH service restarted successfully"
                restarted=true
                break
            fi
        fi
    done
    
    if [[ "$restarted" != "true" ]]; then
        print_warning "Could not restart SSH service automatically"
        print_info "Please restart SSH service manually: sudo systemctl restart ssh"
    fi
}

# Get module information
get_ssh_module_info() {
    cat << EOF
Module: $MODULE_NAME
Description: $MODULE_DESCRIPTION
Version: $MODULE_VERSION

This module hardens SSH daemon configuration by:
- Disabling root login
- Disabling password authentication (key-only)
- Setting SSH protocol version 2
- Disabling X11 forwarding
- Setting secure timeouts and retry limits

Configuration file: $SSH_CONFIG_FILE
Backup location: $SSH_BACKUP_FILE
EOF
}

# Validate SSH hardening configuration
ssh_validate() {
    print_verbose "Validating SSH hardening configuration..."
    local validation_passed=true
    
    # Check if SSH is running
    if ! systemctl is-active --quiet ssh 2>/dev/null && ! systemctl is-active --quiet sshd 2>/dev/null; then
        print_warning "SSH service is not running"
        validation_passed=false
    fi
    
    # Check key SSH security settings
    if [[ -f "$SSH_CONFIG_FILE" ]]; then
        # Check PasswordAuthentication is disabled
        if ! grep -qi "^\s*PasswordAuthentication\s\+no" "$SSH_CONFIG_FILE"; then
            print_error "PasswordAuthentication not properly disabled"
            validation_passed=false
        fi
        
        # Check PermitRootLogin is disabled
        if ! grep -qi "^\s*PermitRootLogin\s\+no" "$SSH_CONFIG_FILE"; then
            print_error "PermitRootLogin not properly disabled"
            validation_passed=false
        fi
        
        # Check X11Forwarding is disabled
        if ! grep -qi "^\s*X11Forwarding\s\+no" "$SSH_CONFIG_FILE"; then
            print_warning "X11Forwarding not disabled"
        fi
        
        # Check MaxAuthTries is set to reasonable value
        if ! grep -qi "^\s*MaxAuthTries\s\+[1-5]" "$SSH_CONFIG_FILE"; then
            print_warning "MaxAuthTries not set to secure value (1-5)"
        fi
    else
        print_error "SSH configuration file not found: $SSH_CONFIG_FILE"
        validation_passed=false
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        print_success "SSH validation passed"
        return 0
    else
        print_error "SSH validation failed"
        return 1
    fi
}

# Module help
show_ssh_help() {
    echo "SSH Hardening Module Help"
    echo "========================="
    echo
    get_ssh_module_info
    echo
    echo "Configuration options:"
    echo "  backup_configs: Create backup before changes (default: true)"
    echo "  dry_run: Preview changes without applying (default: false)"
    echo
}

# Export module functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Module is being sourced
    export -f ssh_apply
    export -f ssh_validate
    export -f get_ssh_module_info
    export -f show_ssh_help
fi