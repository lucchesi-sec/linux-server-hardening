#!/bin/bash

# Sysctl Hardening Module
# Applies kernel security parameters through sysctl

# Module metadata
MODULE_NAME="sysctl"
MODULE_DESCRIPTION="Kernel security parameter hardening via sysctl"
MODULE_VERSION="1.0"

# Module configuration
SYSCTL_CONFIG_FILE="/etc/sysctl.d/99-hardening.conf"
SYSCTL_BACKUP_FILE="/etc/sysctl.d/99-hardening.conf.backup.$(date +%Y%m%d-%H%M%S)"

# Execute sysctl hardening
sysctl_apply() {
    print_info "Starting sysctl hardening..."
    
    # Get configuration
    local config_file=$(get_config "modules.sysctl.config_file" "$SYSCTL_CONFIG_FILE")
    
    # Check if systemctl is available
    if ! command -v systemctl >/dev/null 2>&1; then
        print_warning "systemctl not found, manual sysctl configuration may be required"
    fi
    
    # Backup existing configuration
    if [[ -f "$config_file" ]]; then
        if [[ "$(get_config backup_configs)" == "true" ]]; then
            print_verbose "Backing up sysctl configuration to $SYSCTL_BACKUP_FILE"
            cp "$config_file" "$SYSCTL_BACKUP_FILE"
        fi
    fi
    
    # Apply sysctl settings
    apply_sysctl_settings "$config_file"
    
    # Validate and load configuration
    if validate_sysctl_config "$config_file"; then
        if [[ "$(get_config dry_run)" != "true" ]]; then
            reload_sysctl_settings
        else
            print_info "DRY RUN: Would reload sysctl settings"
        fi
        
        print_success "Sysctl hardening completed successfully"
        return 0
    else
        print_error "Sysctl configuration validation failed"
        return 1
    fi
}

# Apply sysctl security settings
apply_sysctl_settings() {
    local config_file="$1"
    
    print_verbose "Applying sysctl security settings to $config_file..."
    
    if [[ "$(get_config dry_run)" == "true" ]]; then
        print_info "DRY RUN: Would apply sysctl hardening settings:"
        print_info "  - Network security parameters"
        print_info "  - Memory/Process security settings"
        print_info "  - Filesystem protection settings"
        return 0
    fi
    
    # Create sysctl configuration
    create_sysctl_config "$config_file"
    
    print_success "Sysctl configuration written to $config_file"
}

# Create sysctl configuration file
create_sysctl_config() {
    local config_file="$1"
    
    print_verbose "Creating sysctl configuration file..."
    
    # Use configuration values or defaults
    local ip_forward=$(get_config "modules.sysctl.ip_forward" "0")
    local send_redirects=$(get_config "modules.sysctl.send_redirects" "0")
    local accept_redirects=$(get_config "modules.sysctl.accept_redirects" "0")
    local accept_source_route=$(get_config "modules.sysctl.accept_source_route" "0")
    local log_martians=$(get_config "modules.sysctl.log_martians" "1")
    local rp_filter=$(get_config "modules.sysctl.rp_filter" "1")
    local icmp_echo_ignore_broadcasts=$(get_config "modules.sysctl.icmp_echo_ignore_broadcasts" "1")
    local tcp_syncookies=$(get_config "modules.sysctl.tcp_syncookies" "1")
    local randomize_va_space=$(get_config "modules.sysctl.randomize_va_space" "2")
    local dmesg_restrict=$(get_config "modules.sysctl.dmesg_restrict" "1")
    local protected_fifos=$(get_config "modules.sysctl.protected_fifos" "1")
    local protected_hardlinks=$(get_config "modules.sysctl.protected_hardlinks" "1")
    local protected_regular=$(get_config "modules.sysctl.protected_regular" "1")
    local protected_symlinks=$(get_config "modules.sysctl.protected_symlinks" "1")
    
    cat > "$config_file" << EOF
# Hardening sysctl settings (Generated by Linux Hardening Framework)
# Configuration applied: $(date)

# --- Network Settings ---

# IP Spoofing protection
net.ipv4.conf.all.rp_filter = $rp_filter
net.ipv4.conf.default.rp_filter = $rp_filter

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = $icmp_echo_ignore_broadcasts

# Disable source routing
net.ipv4.conf.all.accept_source_route = $accept_source_route
net.ipv6.conf.all.accept_source_route = $accept_source_route
net.ipv4.conf.default.accept_source_route = $accept_source_route
net.ipv6.conf.default.accept_source_route = $accept_source_route

# Ignore send redirects
net.ipv4.conf.all.send_redirects = $send_redirects
net.ipv4.conf.default.send_redirects = $send_redirects

# Disable ICMP redirect acceptance
net.ipv4.conf.all.accept_redirects = $accept_redirects
net.ipv6.conf.all.accept_redirects = $accept_redirects
net.ipv4.conf.default.accept_redirects = $accept_redirects
net.ipv6.conf.default.accept_redirects = $accept_redirects
net.ipv4.conf.all.secure_redirects = $accept_redirects
net.ipv4.conf.default.secure_redirects = $accept_redirects

# Enable SYN cookies to handle SYN floods
net.ipv4.tcp_syncookies = $tcp_syncookies

# Log Martians (packets with impossible source addresses)
net.ipv4.conf.all.log_martians = $log_martians
net.ipv4.conf.default.log_martians = $log_martians

# --- Memory/Process Settings ---

# Enable ASLR (Address Space Layout Randomization)
kernel.randomize_va_space = $randomize_va_space

# Restrict access to kernel logs/pointers (dmesg)
kernel.dmesg_restrict = $dmesg_restrict

# --- Filesystem Settings ---

# Prevent creation of file links/FIFOs in world-writable sticky directories by non-owners
fs.protected_fifos = $protected_fifos
fs.protected_hardlinks = $protected_hardlinks
fs.protected_regular = $protected_regular
fs.protected_symlinks = $protected_symlinks

EOF
    
    print_verbose "Sysctl configuration file created with security settings"
}

# Validate sysctl configuration
validate_sysctl_config() {
    local config_file="$1"
    
    print_verbose "Validating sysctl configuration..."
    
    if [[ "$(get_config dry_run)" == "true" ]]; then
        print_info "DRY RUN: Would validate sysctl configuration"
        return 0
    fi
    
    # Check if file exists and is readable
    if [[ ! -f "$config_file" ]]; then
        print_error "Sysctl configuration file not found: $config_file"
        return 1
    fi
    
    # Test sysctl syntax
    if sysctl -q -p "$config_file" 2>/dev/null; then
        print_verbose "Sysctl configuration syntax is valid"
        return 0
    else
        print_error "Sysctl configuration syntax error in $config_file"
        return 1
    fi
}

# Reload sysctl settings
reload_sysctl_settings() {
    print_verbose "Reloading sysctl settings..."
    
    # Enable systemd-sysctl service
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl enable systemd-sysctl.service >/dev/null 2>&1; then
            print_verbose "systemd-sysctl service enabled"
        else
            print_warning "Failed to enable systemd-sysctl service"
        fi
        
        # Restart the service
        if systemctl restart systemd-sysctl.service 2>/dev/null; then
            print_verbose "systemd-sysctl service restarted"
        else
            print_warning "Failed to restart systemd-sysctl service"
        fi
    fi
    
    # Apply settings for current session
    if sysctl --system >/dev/null 2>&1; then
        print_success "Sysctl settings applied successfully"
    else
        print_error "Failed to apply sysctl settings"
        return 1
    fi
}

# Get module information
get_sysctl_module_info() {
    cat << EOF
Module: $MODULE_NAME
Description: $MODULE_DESCRIPTION
Version: $MODULE_VERSION

This module hardens kernel security parameters by:
- Configuring network security settings (IP spoofing protection, redirects)
- Enabling memory protection (ASLR, dmesg restrictions)
- Setting filesystem protections (symlink/hardlink protection)
- Applying DoS mitigation (SYN cookies, broadcast ignoring)

Configuration file: $(get_config "modules.sysctl.config_file" "$SYSCTL_CONFIG_FILE")
Backup location: $SYSCTL_BACKUP_FILE
EOF
}

# Validate sysctl hardening configuration
sysctl_validate() {
    print_verbose "Validating sysctl hardening configuration..."
    local validation_passed=true
    
    local config_file=$(get_config "modules.sysctl.config_file" "$SYSCTL_CONFIG_FILE")
    
    # Check if configuration file exists
    if [[ ! -f "$config_file" ]]; then
        print_error "Sysctl configuration file not found: $config_file"
        validation_passed=false
    else
        # Check key security settings
        local critical_settings=(
            "net.ipv4.conf.all.rp_filter"
            "net.ipv4.icmp_echo_ignore_broadcasts"
            "net.ipv4.conf.all.accept_source_route"
            "net.ipv4.conf.all.send_redirects"
            "net.ipv4.tcp_syncookies"
            "kernel.randomize_va_space"
            "kernel.dmesg_restrict"
        )
        
        for setting in "${critical_settings[@]}"; do
            if ! grep -q "^${setting}" "$config_file"; then
                print_warning "Critical setting not found in config: $setting"
            fi
        done
        
        # Verify current kernel settings
        local current_aslr=$(sysctl -n kernel.randomize_va_space 2>/dev/null || echo "unknown")
        if [[ "$current_aslr" != "2" ]]; then
            print_error "ASLR not properly enabled (current: $current_aslr, expected: 2)"
            validation_passed=false
        fi
        
        local current_syncookies=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || echo "unknown")
        if [[ "$current_syncookies" != "1" ]]; then
            print_warning "TCP SYN cookies not enabled (current: $current_syncookies)"
        fi
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        print_success "Sysctl validation passed"
        return 0
    else
        print_error "Sysctl validation failed"
        return 1
    fi
}

# Module help
show_sysctl_help() {
    echo "Sysctl Hardening Module Help"
    echo "============================"
    echo
    get_sysctl_module_info
    echo
    echo "Configuration options (modules.sysctl):"
    echo "  config_file: Path to sysctl configuration file"
    echo "  ip_forward: Enable/disable IP forwarding (0/1)"
    echo "  send_redirects: Enable/disable ICMP redirects (0/1)"
    echo "  accept_redirects: Accept ICMP redirects (0/1)"
    echo "  log_martians: Log martian packets (0/1)"
    echo "  randomize_va_space: ASLR level (0-2)"
    echo "  dmesg_restrict: Restrict dmesg access (0/1)"
    echo
}

# Export module functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Module is being sourced
    export -f sysctl_apply
    export -f sysctl_validate
    export -f get_sysctl_module_info
    export -f show_sysctl_help
fi