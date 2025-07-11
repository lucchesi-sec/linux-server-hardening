#!/bin/bash

# Auditd Hardening Module
# Configures comprehensive audit rules for security monitoring

# Module metadata
MODULE_NAME="auditd"
MODULE_DESCRIPTION="Comprehensive audit rules for security monitoring"
MODULE_VERSION="1.0"

# Module configuration
AUDITD_RULES_FILE="/etc/audit/rules.d/99-hardening-rules.rules"
AUDITD_BACKUP_FILE="/etc/audit/rules.d/99-hardening-rules.rules.backup.$(date +%Y%m%d-%H%M%S)"

# Execute auditd hardening
auditd_apply() {
    print_info "Starting auditd hardening..."
    
    # Check if auditd is installed
    if ! command -v auditd >/dev/null 2>&1 && ! command -v auditctl >/dev/null 2>&1; then
        print_warning "Auditd not found, skipping auditd hardening"
        print_info "Install auditd with: sudo apt install auditd"
        return 2
    fi
    
    # Get configuration
    local rules_file=$(get_config "modules.auditd.rules_file" "$AUDITD_RULES_FILE")
    
    # Backup existing configuration
    if [[ -f "$rules_file" ]]; then
        if [[ "$(get_config backup_configs)" == "true" ]]; then
            print_verbose "Backing up auditd rules to $AUDITD_BACKUP_FILE"
            cp "$rules_file" "$AUDITD_BACKUP_FILE"
        fi
    fi
    
    # Apply auditd rules
    apply_auditd_rules "$rules_file"
    
    # Load and validate rules
    if [[ "$(get_config dry_run)" != "true" ]]; then
        if load_auditd_rules "$rules_file"; then
            print_success "Auditd hardening completed successfully"
            return 0
        else
            print_error "Failed to load auditd rules"
            return 1
        fi
    else
        print_info "DRY RUN: Would load auditd rules"
        print_success "Auditd hardening completed (dry run)"
        return 0
    fi
}

# Apply auditd security rules
apply_auditd_rules() {
    local rules_file="$1"
    
    print_verbose "Applying auditd security rules to $rules_file..."
    
    if [[ "$(get_config dry_run)" == "true" ]]; then
        print_info "DRY RUN: Would apply auditd hardening rules:"
        print_info "  - Monitor identity files (passwd, shadow, etc.)"
        print_info "  - Monitor login configuration"
        print_info "  - Monitor SSH configuration"
        print_info "  - Monitor privileged commands"
        print_info "  - Monitor kernel modules"
        print_info "  - Monitor mount operations"
        print_info "  - Monitor file access failures"
        print_info "  - Make configuration immutable"
        return 0
    fi
    
    # Create audit rules configuration
    create_auditd_rules "$rules_file"
    
    print_success "Auditd rules written to $rules_file"
}

# Create auditd rules file
create_auditd_rules() {
    local rules_file="$1"
    
    print_verbose "Creating auditd rules file..."
    
    # Get configuration flags
    local monitor_identity=$(get_config "modules.auditd.monitor_identity_files" "true")
    local monitor_login=$(get_config "modules.auditd.monitor_login_files" "true")
    local monitor_ssh=$(get_config "modules.auditd.monitor_ssh_config" "true")
    local monitor_privileged=$(get_config "modules.auditd.monitor_privileged_commands" "true")
    local monitor_modules=$(get_config "modules.auditd.monitor_modules" "true")
    local monitor_mounts=$(get_config "modules.auditd.monitor_mounts" "true")
    local monitor_access=$(get_config "modules.auditd.monitor_file_access" "true")
    local make_immutable=$(get_config "modules.auditd.make_immutable" "true")
    
    cat > "$rules_file" << EOF
# Auditd rules for hardening (Linux Hardening Framework)
# Configuration applied: $(date)

EOF

    # Identity files monitoring
    if [[ "$monitor_identity" == "true" ]]; then
        cat >> "$rules_file" << 'EOF'
# Monitor changes to user/group files
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

EOF
    fi
    
    # Login configuration monitoring
    if [[ "$monitor_login" == "true" ]]; then
        cat >> "$rules_file" << 'EOF'
# Monitor changes to login definitions
-w /etc/login.defs -p wa -k login
-w /etc/securetty -p wa -k login
-w /etc/pam.d/ -p wa -k login

EOF
    fi
    
    # SSH configuration monitoring
    if [[ "$monitor_ssh" == "true" ]]; then
        cat >> "$rules_file" << 'EOF'
# Monitor changes to SSH configuration
-w /etc/ssh/sshd_config -p wa -k sshd

EOF
    fi
    
    # Privileged commands monitoring
    if [[ "$monitor_privileged" == "true" ]]; then
        cat >> "$rules_file" << 'EOF'
# Monitor use of privileged commands
-a always,exit -F path=/usr/bin/sudo -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/bin/su -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged

EOF
    fi
    
    # Module operations monitoring
    if [[ "$monitor_modules" == "true" ]]; then
        cat >> "$rules_file" << 'EOF'
# Monitor module loading/unloading
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules
-a always,exit -F arch=b32 -S init_module -S delete_module -k modules

EOF
    fi
    
    # Mount operations monitoring
    if [[ "$monitor_mounts" == "true" ]]; then
        cat >> "$rules_file" << 'EOF'
# Monitor mount operations
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts
-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts

EOF
    fi
    
    # File access monitoring
    if [[ "$monitor_access" == "true" ]]; then
        cat >> "$rules_file" << 'EOF'
# Monitor failed access attempts
-a always,exit -F arch=b64 -S openat,truncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S openat,truncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b64 -S openat,truncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S openat,truncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access

EOF
    fi
    
    # Make configuration immutable (must be last)
    if [[ "$make_immutable" == "true" ]]; then
        cat >> "$rules_file" << 'EOF'
# Make the configuration immutable - THIS MUST BE THE LAST RULE LOADED
-e 2
EOF
    fi
    
    print_verbose "Auditd rules file created with security monitoring rules"
}

# Load auditd rules
load_auditd_rules() {
    local rules_file="$1"
    
    print_verbose "Loading auditd rules..."
    
    # Ensure auditd is running
    if command -v systemctl >/dev/null 2>&1; then
        if ! systemctl is-active --quiet auditd; then
            print_info "Starting auditd service..."
            if systemctl start auditd; then
                print_verbose "Auditd service started"
                sleep 1
            else
                print_error "Failed to start auditd service"
                return 1
            fi
        fi
    fi
    
    # Clear existing rules (if not immutable)
    print_verbose "Attempting to clear existing audit rules..."
    if auditctl -D 2>/dev/null; then
        print_verbose "Existing audit rules cleared"
    else
        print_warning "Could not clear existing rules (may be immutable)"
        print_info "This is normal if rules were previously applied"
    fi
    
    # Load rules using augenrules
    print_verbose "Loading audit rules with augenrules..."
    if augenrules --load 2>/dev/null; then
        print_success "Audit rules loaded successfully with augenrules"
        
        # Verify rules are immutable
        if auditctl -s 2>/dev/null | grep -q "enabled 2"; then
            print_success "Audit configuration is now immutable"
        fi
        
        return 0
    else
        print_warning "augenrules failed, attempting service restart..."
        
        # Fallback: restart auditd service
        if systemctl restart auditd 2>/dev/null; then
            print_info "Auditd service restarted"
            
            # Check if rules are loaded and immutable
            sleep 2
            if auditctl -s 2>/dev/null | grep -q "enabled 2"; then
                print_success "Audit rules loaded and configuration is immutable"
                return 0
            else
                print_warning "Audit rules may not be properly loaded"
                return 1
            fi
        else
            print_error "Failed to restart auditd service"
            return 1
        fi
    fi
}

# Get module information
get_auditd_module_info() {
    cat << EOF
Module: $MODULE_NAME
Description: $MODULE_DESCRIPTION
Version: $MODULE_VERSION

This module configures comprehensive audit rules for:
- Identity file monitoring (passwd, shadow, group files)
- Login configuration monitoring (pam.d, login.defs)
- SSH configuration monitoring
- Privileged command execution (sudo, su)
- Kernel module operations
- Mount operations
- Failed file access attempts
- Immutable configuration protection

Configuration file: $(get_config "modules.auditd.rules_file" "$AUDITD_RULES_FILE")
Backup location: $AUDITD_BACKUP_FILE
EOF
}

# Validate auditd hardening configuration
auditd_validate() {
    print_verbose "Validating auditd hardening configuration..."
    local validation_passed=true
    
    local rules_file=$(get_config "modules.auditd.rules_file" "$AUDITD_RULES_FILE")
    
    # Check if auditd is installed
    if ! command -v auditctl >/dev/null 2>&1; then
        print_error "auditctl command not found - auditd not installed"
        validation_passed=false
    fi
    
    # Check if auditd service is running
    if command -v systemctl >/dev/null 2>&1; then
        if ! systemctl is-active --quiet auditd; then
            print_warning "auditd service is not running"
            validation_passed=false
        fi
    fi
    
    # Check if rules file exists
    if [[ ! -f "$rules_file" ]]; then
        print_error "Audit rules file not found: $rules_file"
        validation_passed=false
    else
        # Check for key audit rules
        local critical_rules=(
            "identity"
            "login"
            "sshd"
            "privileged"
            "modules"
        )
        
        for rule in "${critical_rules[@]}"; do
            if ! grep -q "k $rule" "$rules_file"; then
                print_warning "Audit rule not found: $rule"
            fi
        done
        
        # Check if configuration is immutable
        if grep -q "^-e 2" "$rules_file"; then
            print_verbose "Configuration includes immutable setting"
        else
            print_warning "Configuration does not include immutable setting"
        fi
    fi
    
    # Check current audit status
    if command -v auditctl >/dev/null 2>&1; then
        local audit_status=$(auditctl -s 2>/dev/null)
        if [[ -n "$audit_status" ]]; then
            if echo "$audit_status" | grep -q "enabled 2"; then
                print_success "Audit system is enabled and immutable"
            elif echo "$audit_status" | grep -q "enabled 1"; then
                print_warning "Audit system is enabled but not immutable"
            else
                print_error "Audit system is not enabled"
                validation_passed=false
            fi
        else
            print_error "Could not retrieve audit status"
            validation_passed=false
        fi
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        print_success "Auditd validation passed"
        return 0
    else
        print_error "Auditd validation failed"
        return 1
    fi
}

# Module help
show_auditd_help() {
    echo "Auditd Hardening Module Help"
    echo "============================"
    echo
    get_auditd_module_info
    echo
    echo "Configuration options (modules.auditd):"
    echo "  rules_file: Path to audit rules file"
    echo "  monitor_identity_files: Monitor user/group files (true/false)"
    echo "  monitor_login_files: Monitor login configuration (true/false)"
    echo "  monitor_ssh_config: Monitor SSH configuration (true/false)"
    echo "  monitor_privileged_commands: Monitor sudo/su usage (true/false)"
    echo "  monitor_modules: Monitor kernel module operations (true/false)"
    echo "  monitor_mounts: Monitor mount operations (true/false)"
    echo "  monitor_file_access: Monitor failed file access (true/false)"
    echo "  make_immutable: Make configuration immutable (true/false)"
    echo
}

# Export module functions
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Module is being sourced
    export -f auditd_apply
    export -f auditd_validate
    export -f get_auditd_module_info
    export -f show_auditd_help
fi