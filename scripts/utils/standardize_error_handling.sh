#!/bin/bash

# Standardize Error Handling Migration Script
# Converts legacy scripts to use modular framework error handling

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the new output functions
source "$PROJECT_ROOT/src/cli/output.sh"

# Initialize output system
init_output_system

print_header "Legacy Script Error Handling Standardization"

# List of legacy scripts to convert
declare -a LEGACY_SCRIPTS=(
    "$PROJECT_ROOT/install-packages.sh"
    "$PROJECT_ROOT/sysctl/apply-sysctl-config.sh"
    "$PROJECT_ROOT/fail2ban/apply-fail2ban-config.sh"
    "$PROJECT_ROOT/auditd-rules/apply-auditd-rules.sh"
    "$PROJECT_ROOT/password-policy/apply-pam-pwquality.sh"
    "$PROJECT_ROOT/banner/apply-banner.sh"
)

# Create standardized header for legacy scripts
create_legacy_script_header() {
    cat << 'EOF'
#!/bin/bash

# LEGACY SCRIPT - BEING DEPRECATED
# Please migrate to the new modular hardening system: ./harden.sh
# This script will be removed in a future version

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the output functions if available
if [[ -f "$PROJECT_ROOT/src/cli/output.sh" ]]; then
    source "$PROJECT_ROOT/src/cli/output.sh"
    init_output_system
    USE_NEW_OUTPUT=true
else
    USE_NEW_OUTPUT=false
    # Fallback functions for compatibility
    print_error() { echo "ERROR: $1" >&2; }
    print_success() { echo "SUCCESS: $1"; }
    print_warning() { echo "WARNING: $1"; }
    print_info() { echo "INFO: $1"; }
    print_verbose() { [[ "${VERBOSE:-false}" == "true" ]] && echo "VERBOSE: $1"; }
fi

# Legacy compatibility warning
show_deprecation_notice() {
    if [[ "$USE_NEW_OUTPUT" == "true" ]]; then
        print_warning "This script is deprecated. Please use the new modular system:"
        print_info "  ./harden.sh -m <module_name>  # Apply specific module"
        print_info "  ./harden.sh -a                # Apply all modules"
        print_info "  ./harden.sh -i                # Interactive mode"
    else
        echo "WARNING: This script is deprecated. Please use the new modular system:"
        echo "INFO: ./harden.sh -m <module_name> or ./harden.sh -a"
    fi
    echo ""
}

show_deprecation_notice

EOF
}

# Convert echo statements to structured output
convert_script_output() {
    local script_file="$1"
    local temp_file="${script_file}.tmp"
    
    print_info "Converting output statements in: $(basename "$script_file")"
    
    # Create backup
    cp "$script_file" "${script_file}.backup.$(date +%Y%m%d-%H%M%S)"
    
    # Apply conversions
    sed -E '
        # Convert echo "Error: ..." to print_error
        s/echo[[:space:]]+"Error:[[:space:]]*([^"]+)"/print_error "\1"/g
        s/echo[[:space:]]+'\''Error:[[:space:]]*([^'\'']+)'\''/print_error "\1"/g
        
        # Convert echo "Warning: ..." to print_warning  
        s/echo[[:space:]]+"Warning:[[:space:]]*([^"]+)"/print_warning "\1"/g
        s/echo[[:space:]]+'\''Warning:[[:space:]]*([^'\'']+)'\''/print_warning "\1"/g
        
        # Convert echo "SUCCESS: ..." or successful completion messages
        s/echo[[:space:]]+"([^"]*complete[^"]*|[^"]*success[^"]*|[^"]*applied[^"]*)"/print_success "\1"/g
        s/echo[[:space:]]+'\''([^'\'']*complete[^'\'']*|[^'\'']*success[^'\'']*|[^'\'']*applied[^'\'']*)'\''$/print_success "\1"/g
        
        # Convert informational echo statements
        s/echo[[:space:]]+"([A-Z][^"]*\.\.\.|[^"]*ing[[:space:]]+[^"]*\.\.\.|[^"]*Checking[^"]*|[^"]*Applying[^"]*|[^"]*Running[^"]*)"/print_info "\1"/g
        s/echo[[:space:]]+'\''([A-Z][^'\'']*\.\.\.|[^'\'']*ing[[:space:]]+[^'\'']*\.\.\.|[^'\'']*Checking[^'\'']*|[^'\'']*Applying[^'\'']*|[^'\'']*Running[^'\'']*)'\''$/print_info "\1"/g
    ' "$script_file" > "$temp_file"
    
    # Move converted file back
    mv "$temp_file" "$script_file"
    
    print_verbose "Output conversion completed for $(basename "$script_file")"
}

# Update exit error handling 
update_exit_handling() {
    local script_file="$1"
    
    print_verbose "Updating exit handling in: $(basename "$script_file")"
    
    # Replace exit 1 with print_error and exit 1
    sed -i.bak -E '
        # Update standalone exit 1 statements after error messages
        /print_error.*/{
            N
            s/\n[[:space:]]*exit[[:space:]]+1/ \&\& exit 1/
        }
        
        # Update exit statements in conditional blocks
        s/echo[[:space:]]+"Error:[^"]*"[[:space:]]*;[[:space:]]*exit[[:space:]]+1/print_error "&" \&\& exit 1/g
        s/echo[[:space:]]+'\''Error:[^'\'']*'\''[[:space:]]*;[[:space:]]*exit[[:space:]]+1/print_error "&" \&\& exit 1/g
    ' "$script_file"
}

# Add configuration loading capability
add_config_support() {
    local script_file="$1"
    local config_section="$2"
    
    print_verbose "Adding configuration support to: $(basename "$script_file")"
    
    # Add configuration loading after the header
    local config_loader='
# Load configuration if available
CONFIG_FILE="${PROJECT_ROOT}/configs/default.yaml"
if [[ -f "$CONFIG_FILE" && -f "$PROJECT_ROOT/src/core/config_manager.sh" ]]; then
    source "$PROJECT_ROOT/src/core/config_manager.sh"
    load_config "$CONFIG_FILE"
    print_verbose "Configuration loaded from $CONFIG_FILE"
else
    print_warning "Configuration system not available, using defaults"
fi
'
    
    # Insert after the deprecation notice
    awk -v config="$config_loader" '
        /^show_deprecation_notice/ {
            print
            getline
            print
            print config
            next
        }
        { print }
    ' "$script_file" > "${script_file}.tmp" && mv "${script_file}.tmp" "$script_file"
}

# Main conversion process
main() {
    print_section "Starting Legacy Script Standardization"
    
    local converted=0
    local total=${#LEGACY_SCRIPTS[@]}
    
    for script in "${LEGACY_SCRIPTS[@]}"; do
        if [[ -f "$script" ]]; then
            print_progress $((converted + 1)) $total "Converting $(basename "$script")"
            
            # Extract original content (skip shebang and set -e)
            local original_content
            original_content=$(tail -n +3 "$script")
            
            # Create new script with standardized header
            {
                create_legacy_script_header
                echo "# ORIGINAL SCRIPT CONTENT (CONVERTED)"
                echo "$original_content"
            } > "${script}.new"
            
            # Apply output conversions
            convert_script_output "${script}.new"
            
            # Update exit handling
            update_exit_handling "${script}.new"
            
            # Add configuration support
            add_config_support "${script}.new" "$(basename "$(dirname "$script")")"
            
            # Replace original with converted version
            mv "${script}.new" "$script"
            chmod +x "$script"
            
            ((converted++))
            
        else
            print_warning "Script not found: $script"
        fi
    done
    
    update_stats "success"
    print_success "Converted $converted legacy scripts to use standardized error handling"
    
    print_section "Next Steps"
    print_info "1. Test converted scripts to ensure functionality"
    print_info "2. Update configuration files to use YAML settings"
    print_info "3. Create module equivalents for remaining legacy scripts"
    print_info "4. Update documentation to reflect changes"
}

# Validation function
validate_conversions() {
    print_section "Validating Conversions"
    
    for script in "${LEGACY_SCRIPTS[@]}"; do
        if [[ -f "$script" ]]; then
            # Check if script has proper error handling functions
            if grep -q "print_error\|print_success\|print_warning\|print_info" "$script"; then
                print_success "✓ $(basename "$script") - Has standardized output functions"
            else
                print_warning "? $(basename "$script") - May need manual review"
            fi
            
            # Check syntax
            if bash -n "$script" 2>/dev/null; then
                print_verbose "✓ $(basename "$script") - Syntax OK"
            else
                print_error "✗ $(basename "$script") - Syntax errors detected"
            fi
        fi
    done
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
    validate_conversions
    show_execution_summary
fi