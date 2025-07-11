#!/bin/bash

# Interactive CLI Module
# Handles interactive mode prompts and user guidance

# Interactive mode main function
run_interactive_mode() {
    print_section "Interactive Hardening Mode"
    print_info "This mode will guide you through each hardening step"
    print_info "You can choose which modules to apply and see explanations"
    echo
    
    # Show system information
    show_system_info
    echo
    
    # Get user confirmation to proceed
    if ! confirm_action "Do you want to proceed with interactive hardening?"; then
        print_info "Interactive mode cancelled by user"
        return 0
    fi
    
    # Load available modules
    local available_modules=()
    mapfile -t available_modules < <(get_available_modules)
    
    if [[ ${#available_modules[@]} -eq 0 ]]; then
        print_error "No hardening modules found"
        return 1
    fi
    
    print_section "Available Hardening Modules"
    
    # Interactive module selection
    local selected_modules=()
    for module in "${available_modules[@]}"; do
        if prompt_module_selection "$module"; then
            selected_modules+=("$module")
        fi
    done
    
    if [[ ${#selected_modules[@]} -eq 0 ]]; then
        print_warning "No modules selected for hardening"
        return 0
    fi
    
    # Confirm selections
    print_section "Selected Modules"
    for module in "${selected_modules[@]}"; do
        print_success "✓ $module"
    done
    echo
    
    if ! confirm_action "Apply these hardening modules?"; then
        print_info "Hardening cancelled by user"
        return 0
    fi
    
    # Execute selected modules
    execute_selected_modules "${selected_modules[@]}"
}

# Prompt user for module selection
prompt_module_selection() {
    local module="$1"
    local description
    
    description=$(get_module_description "$module")
    
    echo "Module: $module"
    echo "Description: $description"
    echo
    
    if confirm_action "Enable $module module?"; then
        return 0
    else
        return 1
    fi
}

# Get module description
get_module_description() {
    local module="$1"
    
    case "$module" in
        "ssh")
            echo "Secure SSH configuration - disable root login, change default port, key-only auth"
            ;;
        "ufw")
            echo "Configure UFW firewall - enable firewall with secure default rules"
            ;;
        "fail2ban")
            echo "Install and configure fail2ban - protect against brute force attacks"
            ;;
        "sysctl")
            echo "Apply kernel security parameters - network security and system hardening"
            ;;
        "auditd")
            echo "Configure audit logging - track system changes and security events"
            ;;
        *)
            echo "Linux hardening module"
            ;;
    esac
}

# Get available modules
get_available_modules() {
    local modules_dir="$PROJECT_ROOT/src/modules"
    
    if [[ -d "$modules_dir" ]]; then
        find "$modules_dir" -name "*.sh" -type f -exec basename {} .sh \;
    else
        # Fallback to known modules if directory doesn't exist
        echo "ssh"
        echo "ufw"
        echo "fail2ban"
        echo "sysctl"
    fi
}

# Execute selected modules interactively
execute_selected_modules() {
    local modules=("$@")
    
    print_section "Executing Hardening Modules"
    
    for module in "${modules[@]}"; do
        print_info "Preparing to execute: $module"
        
        if confirm_action "Execute $module module now?"; then
            print_info "Executing $module..."
            execute_module "$module"
        else
            print_warning "Skipping $module module"
        fi
        echo
    done
}

# Confirm action with user
confirm_action() {
    local prompt="$1"
    local response
    
    while true; do
        printf "%s [y/N]: " "$prompt"
        read -r response
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo]|"")
                return 1
                ;;
            *)
                print_warning "Please answer yes (y) or no (n)"
                ;;
        esac
    done
}

# Show system information in interactive mode
show_system_info() {
    print_subsection "System Information"
    
    if command -v detect_distribution >/dev/null 2>&1; then
        detect_distribution
        show_distribution_info
    else
        print_info "OS: $(uname -s)"
        print_info "Kernel: $(uname -r)"
        print_info "Architecture: $(uname -m)"
    fi
}

# Interactive help
show_interactive_help() {
    cat << EOF
Interactive Mode Help
====================

Interactive mode guides you through the hardening process step-by-step:

1. System Detection: Shows your current system information
2. Module Selection: Choose which hardening modules to apply
3. Confirmation: Review and confirm your selections
4. Execution: Apply selected hardening with real-time feedback

Available responses:
- y, yes: Confirm action
- n, no: Decline action
- Ctrl+C: Exit at any time

Each module will explain what it does before asking for confirmation.
EOF
}