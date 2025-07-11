#!/bin/bash

# Validation Engine Module
# Handles post-hardening validation and reporting

# Global validation state
declare -a VALIDATION_RESULTS
declare -i VALIDATION_PASSED=0
declare -i VALIDATION_FAILED=0
declare -i VALIDATION_WARNINGS=0

# Main validation function
run_validation() {
    local modules=("$@")
    
    print_section "Running Validation Engine"
    
    # Reset validation state
    VALIDATION_RESULTS=()
    VALIDATION_PASSED=0
    VALIDATION_FAILED=0
    VALIDATION_WARNINGS=0
    
    if [[ ${#modules[@]} -eq 0 ]]; then
        print_info "No modules specified, validating all enabled modules"
        mapfile -t modules < <(get_enabled_modules)
    fi
    
    # Run validation for each module
    for module in "${modules[@]}"; do
        validate_module "$module"
    done
    
    # Generate validation report
    generate_validation_report
    
    # Return appropriate exit code
    if [[ $VALIDATION_FAILED -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Validate individual module
validate_module() {
    local module="$1"
    local result
    
    print_info "Validating $module module..."
    
    case "$module" in
        "ssh")
            validate_ssh_hardening
            result=$?
            ;;
        "ufw")
            validate_ufw_configuration
            result=$?
            ;;
        "fail2ban")
            validate_fail2ban_configuration
            result=$?
            ;;
        "sysctl")
            validate_sysctl_configuration
            result=$?
            ;;
        "auditd")
            validate_auditd_configuration
            result=$?
            ;;
        *)
            print_warning "No validation available for module: $module"
            record_validation_result "$module" "warning" "No validation method available"
            return 2
            ;;
    esac
    
    return $result
}

# SSH hardening validation
validate_ssh_hardening() {
    local module="ssh"
    local config_file="/etc/ssh/sshd_config"
    local issues=()
    
    if [[ ! -f "$config_file" ]]; then
        record_validation_result "$module" "failed" "SSH config file not found"
        return 1
    fi
    
    # Check critical SSH settings
    if ! grep -q "^PermitRootLogin no" "$config_file"; then
        issues+=("Root login not disabled")
    fi
    
    if ! grep -q "^PasswordAuthentication no" "$config_file"; then
        issues+=("Password authentication not disabled")
    fi
    
    if ! grep -q "^Protocol 2" "$config_file"; then
        issues+=("SSH Protocol 2 not enforced")
    fi
    
    # Check if SSH service is running
    if ! systemctl is-active --quiet ssh 2>/dev/null && ! systemctl is-active --quiet sshd 2>/dev/null; then
        issues+=("SSH service not running")
    fi
    
    if [[ ${#issues[@]} -eq 0 ]]; then
        record_validation_result "$module" "passed" "SSH hardening validated successfully"
        return 0
    else
        local message="Issues found: $(IFS=', '; echo "${issues[*]}")"
        record_validation_result "$module" "failed" "$message"
        return 1
    fi
}

# UFW firewall validation
validate_ufw_configuration() {
    local module="ufw"
    
    if ! command -v ufw >/dev/null 2>&1; then
        record_validation_result "$module" "failed" "UFW not installed"
        return 1
    fi
    
    local ufw_status
    ufw_status=$(ufw status 2>/dev/null | head -n1)
    
    if [[ "$ufw_status" == *"active"* ]]; then
        record_validation_result "$module" "passed" "UFW firewall is active"
        return 0
    else
        record_validation_result "$module" "failed" "UFW firewall is not active"
        return 1
    fi
}

# Fail2ban validation
validate_fail2ban_configuration() {
    local module="fail2ban"
    
    if ! command -v fail2ban-client >/dev/null 2>&1; then
        record_validation_result "$module" "failed" "Fail2ban not installed"
        return 1
    fi
    
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        local jail_count
        jail_count=$(fail2ban-client status 2>/dev/null | grep -c "Jail list:" || echo "0")
        
        if [[ $jail_count -gt 0 ]]; then
            record_validation_result "$module" "passed" "Fail2ban is active with configured jails"
            return 0
        else
            record_validation_result "$module" "warning" "Fail2ban is running but no jails configured"
            return 2
        fi
    else
        record_validation_result "$module" "failed" "Fail2ban service not running"
        return 1
    fi
}

# Sysctl validation
validate_sysctl_configuration() {
    local module="sysctl"
    local critical_params=(
        "net.ipv4.ip_forward=0"
        "net.ipv4.conf.all.send_redirects=0"
        "net.ipv4.conf.all.accept_redirects=0"
    )
    local issues=()
    
    for param in "${critical_params[@]}"; do
        local key="${param%=*}"
        local expected_value="${param#*=}"
        local actual_value
        
        actual_value=$(sysctl -n "$key" 2>/dev/null || echo "not_found")
        
        if [[ "$actual_value" != "$expected_value" ]]; then
            issues+=("$key=$actual_value (expected $expected_value)")
        fi
    done
    
    if [[ ${#issues[@]} -eq 0 ]]; then
        record_validation_result "$module" "passed" "Sysctl parameters validated successfully"
        return 0
    else
        local message="Parameter issues: $(IFS=', '; echo "${issues[*]}")"
        record_validation_result "$module" "failed" "$message"
        return 1
    fi
}

# Auditd validation
validate_auditd_configuration() {
    local module="auditd"
    
    if ! command -v auditctl >/dev/null 2>&1; then
        record_validation_result "$module" "failed" "Auditd not installed"
        return 1
    fi
    
    if systemctl is-active --quiet auditd 2>/dev/null; then
        local rules_count
        rules_count=$(auditctl -l 2>/dev/null | wc -l)
        
        if [[ $rules_count -gt 0 ]]; then
            record_validation_result "$module" "passed" "Auditd is active with $rules_count rules"
            return 0
        else
            record_validation_result "$module" "warning" "Auditd is running but no rules configured"
            return 2
        fi
    else
        record_validation_result "$module" "failed" "Auditd service not running"
        return 1
    fi
}

# Record validation result
record_validation_result() {
    local module="$1"
    local status="$2"
    local message="$3"
    
    VALIDATION_RESULTS+=("$module:$status:$message")
    
    case "$status" in
        "passed")
            ((VALIDATION_PASSED++))
            print_success "✓ $module: $message"
            ;;
        "failed")
            ((VALIDATION_FAILED++))
            print_error "✗ $module: $message"
            ;;
        "warning")
            ((VALIDATION_WARNINGS++))
            print_warning "⚠ $module: $message"
            ;;
    esac
}

# Generate validation report
generate_validation_report() {
    print_section "Validation Report"
    
    echo "Summary:"
    print_success "  Passed:   $VALIDATION_PASSED"
    print_warning "  Warnings: $VALIDATION_WARNINGS"
    print_error "  Failed:   $VALIDATION_FAILED"
    echo
    
    local total=$((VALIDATION_PASSED + VALIDATION_FAILED + VALIDATION_WARNINGS))
    if [[ $total -gt 0 ]]; then
        local success_rate=$((VALIDATION_PASSED * 100 / total))
        echo "Success Rate: $success_rate%"
    fi
    
    # Save detailed report to file
    save_validation_report
}

# Save validation report to file
save_validation_report() {
    local report_file="$PROJECT_ROOT/logs/validation-$(date +%Y%m%d-%H%M%S).json"
    local timestamp
    timestamp=$(date -Iseconds)
    
    # Create logs directory if it doesn't exist
    mkdir -p "$(dirname "$report_file")"
    
    # Generate JSON report
    cat > "$report_file" << EOF
{
  "timestamp": "$timestamp",
  "summary": {
    "passed": $VALIDATION_PASSED,
    "failed": $VALIDATION_FAILED,
    "warnings": $VALIDATION_WARNINGS,
    "total": $((VALIDATION_PASSED + VALIDATION_FAILED + VALIDATION_WARNINGS))
  },
  "results": [
EOF
    
    local first=true
    for result in "${VALIDATION_RESULTS[@]}"; do
        local module="${result%%:*}"
        local temp="${result#*:}"
        local status="${temp%%:*}"
        local message="${temp#*:}"
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "    ," >> "$report_file"
        fi
        
        cat >> "$report_file" << EOF
    {
      "module": "$module",
      "status": "$status",
      "message": "$message"
    }
EOF
    done
    
    cat >> "$report_file" << EOF
  ]
}
EOF
    
    print_info "Validation report saved to: $report_file"
}