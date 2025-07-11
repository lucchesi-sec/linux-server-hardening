#!/usr/bin/env bash

# AppArmor Mandatory Access Control Module
# Implements AppArmor MAC for enhanced security

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$PROJECT_ROOT/src/cli/output.sh"
source "$PROJECT_ROOT/src/core/distro_detection.sh"

# Module metadata
MODULE_NAME="apparmor"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="AppArmor Mandatory Access Control hardening"

# AppArmor configuration
APPARMOR_PROFILES_DIR="/etc/apparmor.d"
APPARMOR_LOCAL_DIR="/etc/apparmor.d/local"
CUSTOM_PROFILES_DIR="$PROJECT_ROOT/configs/apparmor"

# Get module information
get_apparmor_module_info() {
    cat << EOF
{
  "name": "$MODULE_NAME",
  "version": "$MODULE_VERSION", 
  "description": "$MODULE_DESCRIPTION",
  "dependencies": ["apparmor", "apparmor-utils"],
  "config_files": [
    "/etc/apparmor.d/",
    "/etc/default/grub"
  ],
  "services": ["apparmor"],
  "supports_dry_run": true,
  "supports_validation": true
}
EOF
}

# Show module help
show_apparmor_help() {
    cat << EOF
AppArmor Module Help

DESCRIPTION:
    Configures AppArmor Mandatory Access Control system for enhanced security.
    AppArmor confines programs to a limited set of resources.

FEATURES:
    - Install and enable AppArmor
    - Configure kernel parameters
    - Enable application profiles
    - Create custom profiles for services
    - Monitor profile violations

CONFIGURATION:
    modules:
      apparmor:
        enabled: true
        enforce_mode: true
        profiles:
          - apache2
          - nginx
          - mysql
          - postgresql
        custom_profiles: true
        violation_logging: true

COMMANDS:
    status      Show AppArmor status and loaded profiles
    enforce     Set profiles to enforce mode
    complain    Set profiles to complain mode
    disable     Disable specific profiles
    reload      Reload all profiles
EOF
}

# Validate AppArmor configuration
validate_apparmor_config() {
    local config_file="$1"
    
    log_info "Validating AppArmor configuration..."
    
    # Check if config file exists
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
    
    log_success "AppArmor configuration validation passed"
    return 0
}

# Check if AppArmor is supported
check_apparmor_support() {
    log_info "Checking AppArmor support..."
    
    # Check kernel support
    if [[ ! -d /sys/kernel/security/apparmor ]]; then
        log_warning "AppArmor not supported in kernel"
        return 1
    fi
    
    # Check if already enabled
    if [[ -f /sys/kernel/security/apparmor/profiles ]]; then
        log_info "AppArmor is supported and available"
        return 0
    fi
    
    log_info "AppArmor kernel support detected"
    return 0
}

# Install AppArmor packages
install_apparmor() {
    log_info "Installing AppArmor packages..."
    
    local distro
    distro=$(detect_distribution)
    
    case "$distro" in
        "ubuntu"|"debian")
            apt-get update
            apt-get install -y apparmor apparmor-utils apparmor-profiles apparmor-profiles-extra
            ;;
        "rhel"|"centos"|"fedora")
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y apparmor apparmor-utils
            else
                yum install -y apparmor apparmor-utils
            fi
            ;;
        *)
            log_error "Unsupported distribution for AppArmor: $distro"
            return 1
            ;;
    esac
    
    log_success "AppArmor packages installed"
}

# Configure kernel parameters for AppArmor
configure_apparmor_kernel() {
    log_info "Configuring kernel parameters for AppArmor..."
    
    local grub_file="/etc/default/grub"
    local backup_file="${grub_file}.bak_$(date +%Y%m%d_%H%M%S)"
    
    # Backup GRUB configuration
    cp "$grub_file" "$backup_file"
    log_info "GRUB configuration backed up to: $backup_file"
    
    # Check if AppArmor is already enabled in GRUB
    if grep -q "apparmor=1" "$grub_file"; then
        log_info "AppArmor already enabled in GRUB configuration"
    else
        # Add AppArmor parameters to GRUB_CMDLINE_LINUX_DEFAULT
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 apparmor=1 security=apparmor"/' "$grub_file"
        
        # Update GRUB
        update-grub
        
        log_success "AppArmor enabled in GRUB configuration"
        log_warning "Reboot required for AppArmor kernel parameters to take effect"
    fi
}

# Enable AppArmor service
enable_apparmor_service() {
    log_info "Enabling AppArmor service..."
    
    # Enable and start AppArmor service
    systemctl enable apparmor
    systemctl start apparmor
    
    # Verify service status
    if systemctl is-active --quiet apparmor; then
        log_success "AppArmor service is running"
    else
        log_error "Failed to start AppArmor service"
        return 1
    fi
}

# Load default profiles
load_default_profiles() {
    log_info "Loading default AppArmor profiles..."
    
    # Common profiles to enable
    local default_profiles=(
        "usr.bin.firefox"
        "usr.sbin.tcpdump" 
        "usr.sbin.apache2"
        "usr.sbin.nginx"
        "usr.bin.dig"
        "usr.bin.host"
        "usr.bin.nslookup"
    )
    
    for profile in "${default_profiles[@]}"; do
        local profile_path="$APPARMOR_PROFILES_DIR/$profile"
        
        if [[ -f "$profile_path" ]]; then
            log_info "Loading profile: $profile"
            aa-enforce "$profile_path" 2>/dev/null || {
                log_warning "Failed to enforce profile: $profile"
                aa-complain "$profile_path" 2>/dev/null || {
                    log_warning "Failed to set complain mode for profile: $profile"
                }
            }
        else
            log_debug "Profile not found: $profile"
        fi
    done
    
    log_success "Default profiles loaded"
}

# Create custom profiles
create_custom_profiles() {
    log_info "Creating custom AppArmor profiles..."
    
    # Create local profiles directory
    mkdir -p "$APPARMOR_LOCAL_DIR"
    
    # Custom SSH profile enhancement
    create_ssh_profile_enhancement
    
    # Custom web server profile
    create_web_server_profile
    
    log_success "Custom profiles created"
}

# Create SSH profile enhancement
create_ssh_profile_enhancement() {
    local ssh_local_profile="$APPARMOR_LOCAL_DIR/usr.sbin.sshd"
    
    cat > "$ssh_local_profile" << 'EOF'
# Local AppArmor profile for SSH daemon
# Enhanced security restrictions

# Additional network restrictions
deny network inet6,
deny network netlink,

# Restrict file access
deny /proc/*/mem r,
deny /proc/*/maps r,
deny /sys/kernel/debug/** rw,

# Restrict capabilities
deny capability sys_ptrace,
deny capability sys_admin,

# Custom logging
owner /var/log/ssh-custom.log w,
EOF
    
    log_info "SSH profile enhancement created"
}

# Create web server profile
create_web_server_profile() {
    local web_profile="$APPARMOR_PROFILES_DIR/usr.local.web-server"
    
    cat > "$web_profile" << 'EOF'
#include <tunables/global>

/usr/local/bin/web-server {
  #include <abstractions/base>
  #include <abstractions/nameservice>
  
  # Executable access
  /usr/local/bin/web-server mr,
  
  # Configuration files
  /etc/web-server/** r,
  owner /var/lib/web-server/** rw,
  
  # Log files
  owner /var/log/web-server/*.log w,
  
  # Network access
  network inet stream,
  network inet6 stream,
  
  # Capabilities
  capability net_bind_service,
  capability setuid,
  capability setgid,
  
  # Deny dangerous access
  deny /proc/*/mem r,
  deny capability sys_admin,
  deny capability sys_ptrace,
}
EOF
    
    log_info "Custom web server profile created"
}

# Show AppArmor status
show_apparmor_status() {
    log_info "AppArmor Status Report"
    echo "===================="
    
    # Check if AppArmor is enabled
    if [[ -f /sys/kernel/security/apparmor/profiles ]]; then
        echo "AppArmor: Enabled"
        
        # Show profile status
        echo
        echo "Loaded Profiles:"
        aa-status 2>/dev/null || {
            echo "Unable to retrieve profile status"
            return 1
        }
        
        # Show enforcement status
        echo
        echo "Profile Modes:"
        apparmor_status 2>/dev/null | grep -E "(enforce|complain|unconfined)" || true
        
        # Show recent violations
        echo
        echo "Recent Violations (last 10):"
        dmesg | grep -i apparmor | tail -10 || echo "No recent violations found"
        
    else
        echo "AppArmor: Not enabled"
        return 1
    fi
}

# Set profiles to enforce mode
enforce_profiles() {
    local profiles=("$@")
    
    if [[ ${#profiles[@]} -eq 0 ]]; then
        log_info "Enforcing all loaded profiles..."
        aa-enforce /etc/apparmor.d/*
    else
        log_info "Enforcing specified profiles..."
        for profile in "${profiles[@]}"; do
            aa-enforce "/etc/apparmor.d/$profile"
        done
    fi
    
    log_success "Profiles set to enforce mode"
}

# Set profiles to complain mode
complain_profiles() {
    local profiles=("$@")
    
    if [[ ${#profiles[@]} -eq 0 ]]; then
        log_info "Setting all loaded profiles to complain mode..."
        aa-complain /etc/apparmor.d/*
    else
        log_info "Setting specified profiles to complain mode..."
        for profile in "${profiles[@]}"; do
            aa-complain "/etc/apparmor.d/$profile"
        done
    fi
    
    log_success "Profiles set to complain mode"
}

# Reload AppArmor profiles
reload_apparmor_profiles() {
    log_info "Reloading AppArmor profiles..."
    
    systemctl reload apparmor
    
    # Wait for reload to complete
    sleep 2
    
    # Verify reload
    if systemctl is-active --quiet apparmor; then
        log_success "AppArmor profiles reloaded successfully"
    else
        log_error "Failed to reload AppArmor profiles"
        return 1
    fi
}

# Generate AppArmor profile for application
generate_profile() {
    local application="$1"
    
    if [[ -z "$application" ]]; then
        log_error "Application name required for profile generation"
        return 1
    fi
    
    log_info "Generating AppArmor profile for: $application"
    
    # Use aa-genprof to generate profile
    aa-genprof "$application" || {
        log_error "Failed to generate profile for: $application"
        return 1
    }
    
    log_success "Profile generated for: $application"
}

# Main AppArmor hardening execution
execute_apparmor_hardening() {
    local config_file="${1:-$PROJECT_ROOT/configs/default.yaml}"
    local dry_run="${2:-false}"
    
    log_info "Starting AppArmor hardening..."
    
    # Validate configuration
    if ! validate_apparmor_config "$config_file"; then
        return 1
    fi
    
    # Check support
    if ! check_apparmor_support; then
        log_error "AppArmor not supported on this system"
        return 1
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY RUN] Would perform AppArmor hardening"
        log_info "[DRY RUN] Would install AppArmor packages"
        log_info "[DRY RUN] Would configure kernel parameters"
        log_info "[DRY RUN] Would enable AppArmor service"
        log_info "[DRY RUN] Would load default profiles"
        log_info "[DRY RUN] Would create custom profiles"
        return 0
    fi
    
    # Install AppArmor
    install_apparmor
    
    # Configure kernel parameters
    configure_apparmor_kernel
    
    # Enable service
    enable_apparmor_service
    
    # Load default profiles
    load_default_profiles
    
    # Create custom profiles
    create_custom_profiles
    
    # Reload profiles
    reload_apparmor_profiles
    
    log_success "AppArmor hardening completed"
    
    # Show status
    show_apparmor_status
}

# Command line interface
main() {
    case "${1:-help}" in
        "execute")
            execute_apparmor_hardening "${2:-}" "${3:-false}"
            ;;
        "status")
            show_apparmor_status
            ;;
        "enforce")
            shift
            enforce_profiles "$@"
            ;;
        "complain")
            shift  
            complain_profiles "$@"
            ;;
        "reload")
            reload_apparmor_profiles
            ;;
        "generate")
            generate_profile "${2:-}"
            ;;
        "info")
            get_apparmor_module_info
            ;;
        "validate")
            validate_apparmor_config "${2:-$PROJECT_ROOT/configs/default.yaml}"
            ;;
        "help"|*)
            show_apparmor_help
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi