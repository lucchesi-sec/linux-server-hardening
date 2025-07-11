#!/bin/bash

# Packages Hardening Module
# Installs essential security packages and configures automatic updates

# Module metadata
MODULE_NAME="packages"
MODULE_DESCRIPTION="Essential security package installation and configuration"
MODULE_VERSION="1.0"

# Execute packages hardening
packages_apply() {
    print_info "Starting packages hardening..."
    
    # Check if we have package manager
    if ! command -v apt >/dev/null 2>&1; then
        print_warning "APT package manager not found, skipping package installation"
        return 2
    fi
    
    # Update package lists first
    update_package_lists
    
    # Install required packages
    install_security_packages
    
    # Configure automatic updates
    configure_automatic_updates
    
    print_success "Packages hardening completed successfully"
    return 0
}

# Update package lists
update_package_lists() {
    print_info "Updating package lists..."
    
    if [[ "$(get_config dry_run)" == "true" ]]; then
        print_info "DRY RUN: Would update package lists with 'apt update'"
        return 0
    fi
    
    if apt update >/dev/null 2>&1; then
        print_success "Package lists updated successfully"
    else
        print_error "Failed to update package lists"
        return 1
    fi
}

# Install security packages
install_security_packages() {
    print_verbose "Installing essential security packages..."
    
    # Get required packages from configuration
    local packages_config=$(get_config "modules.packages.required_packages")
    local default_packages=(
        "ufw"
        "fail2ban"
        "auditd"
        "unattended-upgrades"
        "libpam-pwquality"
    )
    
    # Use configured packages or defaults
    local packages=()
    if [[ -n "$packages_config" ]]; then
        # Parse YAML array (simplified)
        IFS=',' read -ra packages <<< "$packages_config"
    else
        packages=("${default_packages[@]}")
    fi
    
    if [[ "$(get_config dry_run)" == "true" ]]; then
        print_info "DRY RUN: Would install security packages:"
        for package in "${packages[@]}"; do
            print_info "  - $package"
        done
        return 0
    fi
    
    local failed_packages=()
    local installed_packages=()
    
    for package in "${packages[@]}"; do
        # Clean package name
        package=$(echo "$package" | xargs | sed 's/^-[[:space:]]*//')
        
        print_verbose "Installing package: $package"
        
        if install_package "$package"; then
            installed_packages+=("$package")
            print_verbose "✓ $package installed successfully"
        else
            failed_packages+=("$package")
            print_warning "✗ Failed to install $package"
        fi
    done
    
    # Report results
    if [[ ${#installed_packages[@]} -gt 0 ]]; then
        print_success "Successfully installed packages: ${installed_packages[*]}"
    fi
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        print_warning "Failed to install packages: ${failed_packages[*]}"
        print_info "These packages may need to be installed manually"
    fi
    
    return 0
}

# Install individual package
install_package() {
    local package="$1"
    
    # Check if package is already installed
    if dpkg -l "$package" >/dev/null 2>&1; then
        print_verbose "Package $package is already installed"
        return 0
    fi
    
    # Attempt to install package
    if apt install -y "$package" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Configure automatic updates
configure_automatic_updates() {
    print_verbose "Configuring automatic updates..."
    
    local enable_auto_reboot=$(get_config "modules.packages.enable_auto_reboot" "true")
    local auto_reboot_conf=$(get_config "modules.packages.auto_reboot_conf" "/etc/apt/apt.conf.d/99-hardening-auto-reboot.conf")
    
    if [[ "$(get_config dry_run)" == "true" ]]; then
        print_info "DRY RUN: Would configure automatic updates:"
        print_info "  - Enable unattended-upgrades service"
        if [[ "$enable_auto_reboot" == "true" ]]; then
            print_info "  - Enable automatic reboot for updates"
        fi
        return 0
    fi
    
    # Check if unattended-upgrades is installed
    if ! dpkg -l unattended-upgrades >/dev/null 2>&1; then
        print_warning "unattended-upgrades not installed, skipping automatic updates configuration"
        return 1
    fi
    
    # Configure automatic reboot if enabled
    if [[ "$enable_auto_reboot" == "true" ]]; then
        print_verbose "Enabling automatic reboot for unattended-upgrades..."
        
        echo 'Unattended-Upgrade::Automatic-Reboot "true";' > "$auto_reboot_conf"
        
        if [[ $? -eq 0 ]]; then
            print_success "Automatic reboot configuration created: $auto_reboot_conf"
        else
            print_error "Failed to create automatic reboot configuration"
            return 1
        fi
    fi
    
    # Enable and start unattended-upgrades service
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl enable unattended-upgrades >/dev/null 2>&1; then
            print_verbose "unattended-upgrades service enabled"
        else
            print_warning "Failed to enable unattended-upgrades service"
        fi
        
        if systemctl start unattended-upgrades >/dev/null 2>&1; then
            print_verbose "unattended-upgrades service started"
        else
            print_warning "Failed to start unattended-upgrades service"
        fi
    fi
    
    print_success "Automatic updates configured successfully"
    return 0
}

# Get module information
get_packages_module_info() {
    cat << EOF
Module: $MODULE_NAME
Description: $MODULE_DESCRIPTION
Version: $MODULE_VERSION

This module installs and configures:
- Essential security packages (ufw, fail2ban, auditd, etc.)
- Automatic security updates (unattended-upgrades)
- Password quality checking (libpam-pwquality)
- Optional automatic reboot for critical updates

Package manager: APT (Debian/Ubuntu)
EOF
}

# Validate packages hardening configuration
packages_validate() {
    print_verbose "Validating packages hardening configuration..."
    local validation_passed=true
    
    # Check if APT is available
    if ! command -v apt >/dev/null 2>&1; then
        print_error "APT package manager not found"
        validation_passed=false
    fi
    
    # Get required packages from configuration
    local packages_config=$(get_config "modules.packages.required_packages")
    local default_packages=(
        "ufw"
        "fail2ban"
        "auditd"
        "unattended-upgrades"
        "libpam-pwquality"
    )
    
    # Use configured packages or defaults
    local packages=()
    if [[ -n "$packages_config" ]]; then
        IFS=',' read -ra packages <<< "$packages_config"
    else
        packages=("${default_packages[@]}")
    fi
    
    # Check if required packages are installed
    local missing_packages=()
    for package in "${packages[@]}"; do
        # Clean package name
        package=$(echo "$package" | xargs | sed 's/^-[[:space:]]*//')
        
        if ! dpkg -l "$package" >/dev/null 2>&1; then
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        print_error "Missing security packages: ${missing_packages[*]}"
        validation_passed=false
    else
        print_success "All required security packages are installed"
    fi
    
    # Check unattended-upgrades service
    if dpkg -l unattended-upgrades >/dev/null 2>&1; then
        if command -v systemctl >/dev/null 2>&1; then
            if systemctl is-enabled --quiet unattended-upgrades 2>/dev/null; then
                print_success "Automatic updates are enabled"
            else
                print_warning "Automatic updates service is not enabled"
            fi
            
            if systemctl is-active --quiet unattended-upgrades 2>/dev/null; then
                print_verbose "Automatic updates service is running"
            else
                print_warning "Automatic updates service is not running"
            fi
        fi
    else
        print_warning "unattended-upgrades package not installed"
    fi
    
    # Check automatic reboot configuration
    local auto_reboot_conf=$(get_config "modules.packages.auto_reboot_conf" "/etc/apt/apt.conf.d/99-hardening-auto-reboot.conf")
    if [[ -f "$auto_reboot_conf" ]]; then
        if grep -q 'Automatic-Reboot "true"' "$auto_reboot_conf"; then
            print_verbose "Automatic reboot for updates is enabled"
        fi
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        print_success "Packages validation passed"
        return 0
    else
        print_error "Packages validation failed"
        return 1
    fi
}

# Module help
show_packages_help() {
    echo "Packages Hardening Module Help"
    echo "=============================="
    echo
    get_packages_module_info
    echo
    echo "Configuration options (modules.packages):"
    echo "  required_packages: List of essential security packages"
    echo "  enable_auto_reboot: Enable automatic reboot for updates (true/false)"
    echo "  auto_reboot_conf: Path to automatic reboot configuration file"
    echo
    echo "Default packages:"
    echo "  - ufw (firewall)"
    echo "  - fail2ban (intrusion prevention)"
    echo "  - auditd (audit daemon)"
    echo "  - unattended-upgrades (automatic updates)"
    echo "  - libpam-pwquality (password quality)"
    echo
}

# Export module functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Module is being sourced
    export -f packages_apply
    export -f packages_validate
    export -f get_packages_module_info
    export -f show_packages_help
fi