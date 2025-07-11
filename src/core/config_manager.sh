#!/usr/bin/env bash

# Configuration Manager Module
# Handles loading and parsing of configuration files

# Ensure bash 4+ for associative arrays
if [[ ${BASH_VERSION%%.*} -lt 4 ]]; then
    echo "Error: Bash 4.0 or higher required for associative arrays" >&2
    exit 1
fi

# Global configuration variables
declare -A CONFIG
declare -a ENABLED_MODULES

# Load configuration from file
load_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        print_warning "Config file not found: $config_file"
        print_info "Using default configuration"
        load_default_config
        return 1
    fi
    
    print_info "Loading configuration from: $config_file"
    
    # For now, we'll implement a simple key=value parser
    # TODO: Add YAML support in future iterations
    if [[ "$config_file" == *.yaml ]] || [[ "$config_file" == *.yml ]]; then
        parse_yaml_config "$config_file"
    else
        parse_simple_config "$config_file"
    fi
    
    print_verbose "Configuration loaded successfully"
}

# Parse simple key=value configuration
parse_simple_config() {
    local config_file="$1"
    
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        
        # Remove quotes and whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
        
        CONFIG["$key"]="$value"
    done < "$config_file"
    
    # Parse enabled modules
    if [[ -n "${CONFIG[enabled_modules]:-}" ]]; then
        IFS=',' read -ra ENABLED_MODULES <<< "${CONFIG[enabled_modules]}"
        # Trim whitespace from each module name
        for i in "${!ENABLED_MODULES[@]}"; do
            ENABLED_MODULES[$i]=$(echo "${ENABLED_MODULES[$i]}" | xargs)
        done
    fi
}

# Basic YAML parser (simplified)
parse_yaml_config() {
    local config_file="$1"
    
    print_verbose "Parsing YAML configuration: $config_file"
    
    # Simple YAML parser - handles basic key: value and lists
    local current_section=""
    local in_modules_section=false
    local in_enabled_modules=false
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Remove leading/trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Check for main sections
        if [[ "$line" =~ ^[a-zA-Z_][a-zA-Z0-9_]*: ]]; then
            local key="${line%%:*}"
            local value="${line#*: }"
            
            case "$key" in
                "enabled_modules")
                    in_enabled_modules=true
                    ENABLED_MODULES=()
                    ;;
                "modules")
                    in_modules_section=true
                    current_section="modules"
                    ;;
                *)
                    CONFIG["$key"]="$value"
                    in_enabled_modules=false
                    in_modules_section=false
                    ;;
            esac
        # Handle list items under enabled_modules
        elif [[ "$in_enabled_modules" == "true" && "$line" =~ ^-[[:space:]]+ ]]; then
            local module_name="${line#- }"
            ENABLED_MODULES+=("$module_name")
        # Handle nested module configuration
        elif [[ "$in_modules_section" == "true" && "$line" =~ ^[[:space:]]+[a-zA-Z_] ]]; then
            local nested_line="${line#  }"  # Remove 2-space indent
            if [[ "$nested_line" =~ : ]]; then
                local nested_key="${nested_line%%:*}"
                local nested_value="${nested_line#*: }"
                CONFIG["modules.${current_section}.${nested_key}"]="$nested_value"
            fi
        fi
    done < "$config_file"
    
    # Ensure we have some enabled modules
    if [[ ${#ENABLED_MODULES[@]} -eq 0 ]]; then
        print_warning "No enabled modules found in YAML, loading defaults"
        ENABLED_MODULES=("ssh" "ufw" "sysctl" "fail2ban")
    fi
    
    print_success "YAML configuration parsed successfully"
}

# Load default configuration
load_default_config() {
    # Default settings
    CONFIG[dry_run]="${DRY_RUN:-false}"
    CONFIG[verbose]="${VERBOSE:-false}"
    CONFIG[backup_configs]="true"
    CONFIG[log_level]="info"
    CONFIG[output_format]="colored"
    
    # Default enabled modules
    ENABLED_MODULES=(
        "ssh"
        "ufw"
        "sysctl"
        "fail2ban"
    )
    
    print_verbose "Default configuration loaded"
}

# Get configuration value
get_config() {
    local key="$1"
    local default="${2:-}"
    
    echo "${CONFIG[$key]:-$default}"
}

# Set configuration value
set_config() {
    local key="$1"
    local value="$2"
    
    CONFIG["$key"]="$value"
}

# Check if module is enabled
is_module_enabled() {
    local module="$1"
    
    for enabled_module in "${ENABLED_MODULES[@]}"; do
        if [[ "$enabled_module" == "$module" ]]; then
            return 0
        fi
    done
    return 1
}

# Get list of enabled modules
get_enabled_modules() {
    printf '%s\n' "${ENABLED_MODULES[@]}"
}

# Show current configuration
show_config() {
    print_section "Current Configuration"
    
    echo "General Settings:"
    for key in "${!CONFIG[@]}"; do
        printf "  %-20s: %s\n" "$key" "${CONFIG[$key]}"
    done
    
    echo
    echo "Enabled Modules:"
    for module in "${ENABLED_MODULES[@]}"; do
        printf "  - %s\n" "$module"
    done
}

# Validate configuration
validate_config() {
    local valid=true
    
    # Check if enabled modules exist
    for module in "${ENABLED_MODULES[@]}"; do
        local module_file="$PROJECT_ROOT/src/modules/${module}.sh"
        if [[ ! -f "$module_file" ]]; then
            print_error "Module not found: $module ($module_file)"
            valid=false
        fi
    done
    
    if [[ "$valid" == "true" ]]; then
        print_success "Configuration validation passed"
        return 0
    else
        print_error "Configuration validation failed"
        return 1
    fi
}