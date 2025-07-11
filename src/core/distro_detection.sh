#!/bin/bash

# Distribution Detection Module
# Identifies Linux distribution and system characteristics

# Global variables for distribution info
DISTRO_ID=""
DISTRO_VERSION=""
DISTRO_CODENAME=""
PACKAGE_MANAGER=""
INIT_SYSTEM=""

# Detect the Linux distribution
detect_distribution() {
    print_info "Detecting Linux distribution..."
    
    # Try /etc/os-release first (standard)
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_VERSION="${VERSION_ID:-unknown}"
        DISTRO_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-unknown}}"
    # Fallback to other methods
    elif [[ -f /etc/lsb-release ]]; then
        source /etc/lsb-release
        DISTRO_ID="${DISTRIB_ID,,}"
        DISTRO_VERSION="${DISTRIB_RELEASE:-unknown}"
        DISTRO_CODENAME="${DISTRIB_CODENAME:-unknown}"
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO_ID="rhel"
        DISTRO_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | head -1)
    else
        print_warning "Could not determine distribution"
        DISTRO_ID="unknown"
    fi
    
    # Detect package manager
    detect_package_manager
    
    # Detect init system
    detect_init_system
    
    print_success "Distribution detected: $DISTRO_ID $DISTRO_VERSION"
}

# Detect package manager
detect_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        PACKAGE_MANAGER="apt"
    elif command -v yum >/dev/null 2>&1; then
        PACKAGE_MANAGER="yum"
    elif command -v dnf >/dev/null 2>&1; then
        PACKAGE_MANAGER="dnf"
    elif command -v pacman >/dev/null 2>&1; then
        PACKAGE_MANAGER="pacman"
    elif command -v zypper >/dev/null 2>&1; then
        PACKAGE_MANAGER="zypper"
    else
        PACKAGE_MANAGER="unknown"
    fi
}

# Detect init system
detect_init_system() {
    if [[ -d /run/systemd/system ]]; then
        INIT_SYSTEM="systemd"
    elif [[ -f /sbin/initctl ]] && /sbin/initctl version 2>/dev/null | grep -q upstart; then
        INIT_SYSTEM="upstart"
    elif [[ -f /etc/init.d/cron ]] && [[ ! -h /etc/init.d/cron ]]; then
        INIT_SYSTEM="sysv"
    else
        INIT_SYSTEM="unknown"
    fi
}

# Show detailed distribution information
show_distribution_info() {
    cat << EOF
System Information:
  Distribution: $DISTRO_ID
  Version: $DISTRO_VERSION
  Codename: $DISTRO_CODENAME
  Package Manager: $PACKAGE_MANAGER
  Init System: $INIT_SYSTEM
  Kernel: $(uname -r)
  Architecture: $(uname -m)
EOF
}

# Check if distribution is supported
is_supported_distro() {
    case "$DISTRO_ID" in
        ubuntu|debian|centos|rhel|fedora|arch|opensuse|sles)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Get distro-specific configuration
get_distro_config() {
    local config_file="$PROJECT_ROOT/configs/distros/${DISTRO_ID}.yaml"
    if [[ -f "$config_file" ]]; then
        echo "$config_file"
    else
        echo "$PROJECT_ROOT/configs/distros/default.yaml"
    fi
}