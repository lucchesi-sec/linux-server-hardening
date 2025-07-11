#!/bin/bash

# Module Dispatcher
# Handles loading, execution order, and coordination of hardening modules

# Global arrays for module management
declare -a MODULE_EXECUTION_ORDER
declare -A MODULE_STATUS
declare -A MODULE_DEPENDENCIES

# Initialize module system
init_module_system() {
    print_info "Initializing module system..."
    
    # Discover available modules
    discover_modules
    
    # Calculate execution order based on dependencies
    calculate_execution_order
    
    print_success "Module system initialized"
}

# Discover available modules in the modules directory
discover_modules() {
    local modules_dir="$PROJECT_ROOT/src/modules"
    
    if [[ ! -d "$modules_dir" ]]; then
        print_error "Modules directory not found: $modules_dir"
        return 1
    fi
    
    print_verbose "Discovering modules in: $modules_dir"
    
    for module_file in "$modules_dir"/*.sh; do
        if [[ -f "$module_file" ]]; then
            local module_name=$(basename "$module_file" .sh)
            print_verbose "Found module: $module_name"
            
            # Load module metadata if it exists
            load_module_metadata "$module_name"
        fi
    done
}

# Load module metadata and dependencies
load_module_metadata() {
    local module_name="$1"
    local module_file="$PROJECT_ROOT/src/modules/${module_name}.sh"
    
    # Source the module to get metadata
    if [[ -f "$module_file" ]]; then
        # Extract dependencies from module file (if defined)
        local deps=$(grep "^# DEPENDENCIES:" "$module_file" 2>/dev/null | cut -d: -f2 | xargs)
        if [[ -n "$deps" ]]; then
            MODULE_DEPENDENCIES["$module_name"]="$deps"
        fi
        
        MODULE_STATUS["$module_name"]="available"
    fi
}

# Calculate execution order based on dependencies
calculate_execution_order() {
    print_verbose "Calculating module execution order..."
    
    MODULE_EXECUTION_ORDER=()
    local -a remaining_modules
    
    # Start with enabled modules
    for module in "${ENABLED_MODULES[@]}"; do
        remaining_modules+=("$module")
    done
    
    # Simple dependency resolution (topological sort)
    while [[ ${#remaining_modules[@]} -gt 0 ]]; do
        local added_module=false
        
        for i in "${!remaining_modules[@]}"; do
            local module="${remaining_modules[$i]}"
            local deps="${MODULE_DEPENDENCIES[$module]:-}"
            local can_execute=true
            
            # Check if all dependencies are already in execution order
            if [[ -n "$deps" ]]; then
                for dep in $deps; do
                    if ! [[ " ${MODULE_EXECUTION_ORDER[*]} " =~ " $dep " ]]; then
                        can_execute=false
                        break
                    fi
                done
            fi
            
            if [[ "$can_execute" == "true" ]]; then
                MODULE_EXECUTION_ORDER+=("$module")
                unset 'remaining_modules[$i]'
                remaining_modules=("${remaining_modules[@]}")  # Reindex array
                added_module=true
                break
            fi
        done
        
        # Prevent infinite loop if circular dependencies exist
        if [[ "$added_module" == "false" ]]; then
            print_warning "Possible circular dependency detected, adding remaining modules"
            MODULE_EXECUTION_ORDER+=("${remaining_modules[@]}")
            break
        fi
    done
    
    print_verbose "Execution order: ${MODULE_EXECUTION_ORDER[*]}"
}

# Run automated mode (all enabled modules)
run_automated_mode() {
    print_info "Running in automated mode..."
    
    init_module_system
    
    if [[ ${#MODULE_EXECUTION_ORDER[@]} -eq 0 ]]; then
        print_warning "No modules to execute"
        return 0
    fi
    
    local total=${#MODULE_EXECUTION_ORDER[@]}
    local current=0
    
    for module in "${MODULE_EXECUTION_ORDER[@]}"; do
        ((current++))
        print_progress "$current" "$total" "Processing $module"
        
        execute_module "$module"
    done
    
    echo  # New line after progress
}

# Execute a single module
execute_module() {
    local module_name="$1"
    local module_file="$PROJECT_ROOT/src/modules/${module_name}.sh"
    
    if [[ ! -f "$module_file" ]]; then
        print_error "Module file not found: $module_file"
        MODULE_STATUS["$module_name"]="error"
        update_stats "error"
        return 1
    fi
    
    print_info "Executing module: $module_name"
    
    # Source the module
    if ! source "$module_file"; then
        print_error "Failed to load module: $module_name"
        MODULE_STATUS["$module_name"]="error"
        update_stats "error"
        return 1
    fi
    
    # Check if module has required functions
    if ! declare -f "${module_name}_apply" >/dev/null; then
        print_error "Module $module_name missing apply function"
        MODULE_STATUS["$module_name"]="error"
        update_stats "error"
        return 1
    fi
    
    # Execute pre-check if exists
    if declare -f "${module_name}_pre_check" >/dev/null; then
        print_verbose "Running pre-check for $module_name"
        if ! "${module_name}_pre_check"; then
            print_warning "Pre-check failed for $module_name, skipping"
            MODULE_STATUS["$module_name"]="skipped"
            update_stats "warning"
            return 0
        fi
    fi
    
    # Execute the module
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "[DRY RUN] Would execute: $module_name"
        MODULE_STATUS["$module_name"]="dry_run"
        update_stats "success"
    else
        if "${module_name}_apply"; then
            print_success "Module $module_name completed successfully"
            MODULE_STATUS["$module_name"]="success"
            update_stats "success"
            
            # Run validation if function exists
            if declare -f "${module_name}_validate" >/dev/null; then
                validate_module "$module_name"
            fi
        else
            print_error "Module $module_name failed"
            MODULE_STATUS["$module_name"]="error"
            update_stats "error"
            return 1
        fi
    fi
}

# Validate a module's execution
validate_module() {
    local module_name="$1"
    
    print_verbose "Validating module: $module_name"
    
    if "${module_name}_validate"; then
        print_success "Validation passed for $module_name"
        return 0
    else
        print_warning "Validation failed for $module_name"
        update_stats "warning"
        return 1
    fi
}

# Run validation for all executed modules
run_validation_only() {
    print_info "Running validation for all modules..."
    
    init_module_system
    
    for module in "${MODULE_EXECUTION_ORDER[@]}"; do
        local module_file="$PROJECT_ROOT/src/modules/${module}.sh"
        
        if [[ -f "$module_file" ]]; then
            source "$module_file"
            
            if declare -f "${module}_validate" >/dev/null; then
                validate_module "$module"
            else
                print_warning "No validation function for module: $module"
            fi
        fi
    done
}

# Show module status
show_module_status() {
    print_section "Module Status"
    
    print_table_header "Module" "Status" "Dependencies"
    
    for module in "${MODULE_EXECUTION_ORDER[@]}"; do
        local status="${MODULE_STATUS[$module]:-unknown}"
        local deps="${MODULE_DEPENDENCIES[$module]:-none}"
        print_table_row "$module" "$status" "$deps"
    done
}