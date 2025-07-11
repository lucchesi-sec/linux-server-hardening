#!/usr/bin/env bash

# Linux Server Hardening Platform
# Main entry point for the modular hardening system

set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Source core modules
source "$PROJECT_ROOT/src/core/distro_detection.sh"
source "$PROJECT_ROOT/src/core/config_manager.sh"
source "$PROJECT_ROOT/src/core/module_dispatcher.sh"
source "$PROJECT_ROOT/src/cli/output.sh"
source "$PROJECT_ROOT/src/cli/interactive.sh"
source "$PROJECT_ROOT/src/validation/engine.sh"

# Default configuration
DEFAULT_CONFIG="$PROJECT_ROOT/configs/default.yaml"
VERBOSE=false
DRY_RUN=false
INTERACTIVE=false
CONFIG_FILE=""

# Display usage information
show_help() {
    cat << EOF
Linux Server Hardening Platform

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -a, --apply         Apply all enabled modules from config
    -i, --interactive   Interactive mode (step-by-step prompts)
    -c, --config FILE   Use specified config file (default: configs/default.yaml)
    -v, --verbose       Verbose output (module execution details)
    --dry-run          Preview actions without making changes
    --validate         Only run validation engine
    --detect           Show distribution detection information
    --help             Show this help message

EXAMPLES:
    $0 --detect                    # Show system information
    $0 -a                         # Apply all default hardening
    $0 -i                         # Interactive mode
    $0 -c custom.yaml --dry-run   # Preview with custom config
    $0 --validate                 # Only validate current state

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--apply)
                ACTION="apply"
                shift
                ;;
            -i|--interactive)
                INTERACTIVE=true
                ACTION="interactive"
                shift
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --validate)
                ACTION="validate"
                shift
                ;;
            --detect)
                ACTION="detect"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
}

# Main execution function
main() {
    local action="${ACTION:-}"
    
    # Initialize output system
    init_output_system
    
    # Show header
    print_header "Linux Server Hardening Platform"
    
    # Detect distribution
    print_section "System Detection"
    detect_distribution
    
    # Load configuration
    print_section "Configuration"
    local config_file="${CONFIG_FILE:-$DEFAULT_CONFIG}"
    load_config "$config_file"
    
    # Execute based on action
    case "$action" in
        "detect")
            print_section "Distribution Information"
            show_distribution_info
            ;;
        "apply")
            print_section "Applying Hardening"
            if [[ "$INTERACTIVE" == "true" ]]; then
                run_interactive_mode
            else
                run_automated_mode
            fi
            ;;
        "interactive")
            print_section "Interactive Mode"
            run_interactive_mode
            ;;
        "validate")
            print_section "Validation"
            run_validation_only
            ;;
        *)
            print_error "No action specified. Use --help for usage information."
            exit 1
            ;;
    esac
    
    # Show summary
    print_section "Summary"
    show_execution_summary
}

# Set default action if none specified
ACTION=""

# Parse arguments and run
parse_args "$@"
main