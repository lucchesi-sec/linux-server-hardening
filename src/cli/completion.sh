#!/bin/bash

# Bash Completion Script for Linux Server Hardening Platform
# Provides intelligent autocomplete for commands, options, and modules

# Main completion function
_harden_completions() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Main command options
    local main_opts="--apply --interactive --config --verbose --dry-run --validate --detect --help --dashboard --wizard --modules --profiles --compliance --fleet --api --theme --completion"
    local short_opts="-a -i -c -v -h"
    
    # Module names
    local modules="ssh ufw fail2ban sysctl auditd apparmor aide clamav rkhunter lynis packages banner"
    
    # Profile names
    local profiles="standard_baseline financial_services healthcare development high_security custom"
    
    # Compliance frameworks
    local frameworks="cis_ubuntu_22_04 nist_800_53 pci_dss iso_27001 soc2 hipaa"
    
    # Configuration files
    local configs="default.yaml standard.yaml financial.yaml healthcare.yaml development.yaml high_security.yaml"
    
    # Themes
    local themes="default dark minimal"
    
    # Handle different contexts
    case "${prev}" in
        --config|-c)
            # Complete configuration files
            _complete_config_files
            return 0
            ;;
        --modules|-m)
            # Complete module names
            COMPREPLY=($(compgen -W "${modules}" -- ${cur}))
            return 0
            ;;
        --profile|-p)
            # Complete profile names
            COMPREPLY=($(compgen -W "${profiles}" -- ${cur}))
            return 0
            ;;
        --framework|-f)
            # Complete compliance frameworks
            COMPREPLY=($(compgen -W "${frameworks}" -- ${cur}))
            return 0
            ;;
        --theme|-t)
            # Complete theme names
            COMPREPLY=($(compgen -W "${themes}" -- ${cur}))
            return 0
            ;;
        --output|-o)
            # Complete output formats
            COMPREPLY=($(compgen -W "json yaml html csv" -- ${cur}))
            return 0
            ;;
        --log-level)
            # Complete log levels
            COMPREPLY=($(compgen -W "debug info warning error critical" -- ${cur}))
            return 0
            ;;
    esac
    
    # Handle subcommands
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        # First argument - main commands and options
        COMPREPLY=($(compgen -W "${main_opts} ${short_opts}" -- ${cur}))
        return 0
    fi
    
    # Handle second level completions
    local first_arg="${COMP_WORDS[1]}"
    case "${first_arg}" in
        --modules|-m)
            _complete_module_subcommands
            ;;
        --compliance)
            _complete_compliance_subcommands
            ;;
        --servers)
            _complete_server_subcommands
            ;;
        --api)
            _complete_api_subcommands
            ;;
        --dashboard)
            _complete_dashboard_subcommands
            ;;
        *)
            # Default completion for remaining arguments
            _complete_default_args
            ;;
    esac
}

# Complete configuration files
_complete_config_files() {
    local config_dir="configs"
    local files=""
    
    # Look for config files in the configs directory
    if [[ -d "$config_dir" ]]; then
        files=$(find "$config_dir" -name "*.yaml" -o -name "*.yml" 2>/dev/null | sed 's|^configs/||')
    fi
    
    # Add default configs if directory doesn't exist
    if [[ -z "$files" ]]; then
        files="$configs"
    fi
    
    COMPREPLY=($(compgen -W "${files}" -- ${cur}))
}

# Complete module subcommands
_complete_module_subcommands() {
    local module_cmds="list info enable disable status configure help"
    
    if [[ ${COMP_CWORD} -eq 2 ]]; then
        COMPREPLY=($(compgen -W "${module_cmds}" -- ${cur}))
    elif [[ ${COMP_CWORD} -eq 3 ]]; then
        case "${COMP_WORDS[2]}" in
            info|enable|disable|status|configure)
                COMPREPLY=($(compgen -W "${modules}" -- ${cur}))
                ;;
        esac
    fi
}

# Complete compliance subcommands
_complete_compliance_subcommands() {
    local compliance_cmds="scan report list frameworks profiles init update"
    
    if [[ ${COMP_CWORD} -eq 2 ]]; then
        COMPREPLY=($(compgen -W "${compliance_cmds}" -- ${cur}))
    elif [[ ${COMP_CWORD} -eq 3 ]]; then
        case "${COMP_WORDS[2]}" in
            scan|report)
                COMPREPLY=($(compgen -W "${frameworks}" -- ${cur}))
                ;;
            profiles)
                COMPREPLY=($(compgen -W "${profiles}" -- ${cur}))
                ;;
        esac
    fi
}

# Complete server subcommands
_complete_server_subcommands() {
    local server_cmds="list register deploy status logs metrics nodes"
    
    if [[ ${COMP_CWORD} -eq 2 ]]; then
        COMPREPLY=($(compgen -W "${fleet_cmds}" -- ${cur}))
    elif [[ ${COMP_CWORD} -eq 3 ]]; then
        case "${COMP_WORDS[2]}" in
            deploy)
                COMPREPLY=($(compgen -W "${profiles}" -- ${cur}))
                ;;
            logs|status)
                # Complete node names (would need to be dynamic)
                COMPREPLY=($(compgen -W "node1 node2 node3" -- ${cur}))
                ;;
        esac
    fi
}

# Complete API subcommands
_complete_api_subcommands() {
    local api_cmds="start stop status config test endpoints docs"
    
    if [[ ${COMP_CWORD} -eq 2 ]]; then
        COMPREPLY=($(compgen -W "${api_cmds}" -- ${cur}))
    fi
}

# Complete dashboard subcommands
_complete_dashboard_subcommands() {
    local dashboard_cmds="start overview security compliance network logs modules help"
    
    if [[ ${COMP_CWORD} -eq 2 ]]; then
        COMPREPLY=($(compgen -W "${dashboard_cmds}" -- ${cur}))
    fi
}

# Complete default arguments
_complete_default_args() {
    # Check if we're in a flag that expects a value
    case "${cur}" in
        -*)
            # Complete remaining flags
            local remaining_opts="--verbose --dry-run --help --force --quiet --debug"
            COMPREPLY=($(compgen -W "${remaining_opts}" -- ${cur}))
            ;;
        *)
            # Complete files or modules depending on context
            _complete_context_sensitive
            ;;
    esac
}

# Context-sensitive completion
_complete_context_sensitive() {
    local words="${COMP_WORDS[*]}"
    
    # If "modules" appears in the command line, suggest module names
    if [[ "$words" =~ modules ]]; then
        COMPREPLY=($(compgen -W "${modules}" -- ${cur}))
    # If "profile" appears, suggest profiles
    elif [[ "$words" =~ profile ]]; then
        COMPREPLY=($(compgen -W "${profiles}" -- ${cur}))
    # If "compliance" appears, suggest frameworks
    elif [[ "$words" =~ compliance ]]; then
        COMPREPLY=($(compgen -W "${frameworks}" -- ${cur}))
    # Default to files and directories
    else
        COMPREPLY=($(compgen -f -- ${cur}))
    fi
}

# Advanced completion with descriptions
_harden_completions_with_descriptions() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Store descriptions for help display
    local -A descriptions=(
        ["--apply"]="Apply all enabled hardening modules"
        ["--interactive"]="Run interactive wizard mode"
        ["--config"]="Specify configuration file"
        ["--verbose"]="Enable verbose output"
        ["--dry-run"]="Preview changes without applying"
        ["--validate"]="Run validation checks only"
        ["--detect"]="Show system detection information"
        ["--dashboard"]="Launch real-time monitoring dashboard"
        ["--wizard"]="Start interactive security wizard"
        ["--modules"]="Manage hardening modules"
        ["--profiles"]="Manage compliance profiles"
        ["--compliance"]="Run compliance operations"
        ["--servers"]="Multi-server management operations"
        ["--api"]="API server operations"
        ["--theme"]="Set CLI theme"
        ["ssh"]="SSH daemon hardening"
        ["ufw"]="UFW firewall configuration"
        ["fail2ban"]="Fail2ban intrusion prevention"
        ["sysctl"]="Kernel security parameters"
        ["auditd"]="Audit logging configuration"
        ["apparmor"]="AppArmor mandatory access control"
        ["aide"]="AIDE file integrity monitoring"
        ["standard_baseline"]="Standard security baseline"
        ["financial_services"]="PCI DSS and SOC2 compliance"
        ["healthcare"]="HIPAA compliance configuration"
        ["development"]="Development environment security"
        ["high_security"]="Maximum security hardening"
    )
    
    # Generate completions with descriptions
    local options=""
    case "${prev}" in
        harden.sh|./harden.sh)
            options="--apply --interactive --config --verbose --dry-run --validate --detect --dashboard --wizard --modules --profiles --compliance --fleet --api --theme --help"
            ;;
        --modules|-m)
            options="ssh ufw fail2ban sysctl auditd apparmor aide clamav rkhunter lynis"
            ;;
        --profile|-p)
            options="standard_baseline financial_services healthcare development high_security custom"
            ;;
    esac
    
    if [[ -n "$options" ]]; then
        COMPREPLY=($(compgen -W "${options}" -- ${cur}))
        
        # If only one completion, show description
        if [[ ${#COMPREPLY[@]} -eq 1 ]]; then
            local desc="${descriptions[${COMPREPLY[0]}]}"
            if [[ -n "$desc" ]]; then
                COMPREPLY[0]="${COMPREPLY[0]} # $desc"
            fi
        fi
    fi
}

# Smart completion that adapts to user patterns
_harden_smart_completions() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local history_file="$HOME/.harden_completion_history"
    
    # Log completion usage
    if [[ -n "$cur" && ${#cur} -gt 2 ]]; then
        echo "$cur" >> "$history_file"
    fi
    
    # Get frequent completions
    local frequent_completions=""
    if [[ -f "$history_file" ]]; then
        frequent_completions=$(sort "$history_file" | uniq -c | sort -nr | head -10 | awk '{print $2}')
    fi
    
    # Combine with standard completions
    _harden_completions
    
    # Add frequent items to the front
    if [[ -n "$frequent_completions" ]]; then
        local frequent_matches=($(compgen -W "${frequent_completions}" -- ${cur}))
        if [[ ${#frequent_matches[@]} -gt 0 ]]; then
            COMPREPLY=("${frequent_matches[@]}" "${COMPREPLY[@]}")
        fi
    fi
}

# Generate completion script
generate_completion_script() {
    cat << 'EOF'
# Bash completion script for Linux Server Hardening Platform
# Source this file or add to your ~/.bashrc

_harden_complete() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    local main_opts="--apply --interactive --config --verbose --dry-run --validate --detect --help --dashboard --wizard --modules --profiles --compliance --fleet --api --theme"
    local modules="ssh ufw fail2ban sysctl auditd apparmor aide clamav rkhunter lynis packages banner"
    local profiles="standard_baseline financial_services healthcare development high_security custom"
    local frameworks="cis_ubuntu_22_04 nist_800_53 pci_dss iso_27001 soc2 hipaa"
    
    case "${prev}" in
        --config|-c)
            COMPREPLY=($(compgen -f -X '!*.yaml' -X '!*.yml' -- ${cur}))
            return 0
            ;;
        --modules|-m)
            COMPREPLY=($(compgen -W "${modules}" -- ${cur}))
            return 0
            ;;
        --profile|-p)
            COMPREPLY=($(compgen -W "${profiles}" -- ${cur}))
            return 0
            ;;
        --framework|-f)
            COMPREPLY=($(compgen -W "${frameworks}" -- ${cur}))
            return 0
            ;;
        --theme|-t)
            COMPREPLY=($(compgen -W "default dark minimal" -- ${cur}))
            return 0
            ;;
    esac
    
    if [[ ${cur} == -* ]]; then
        COMPREPLY=($(compgen -W "${main_opts}" -- ${cur}))
        return 0
    fi
    
    case "${COMP_WORDS[1]}" in
        --modules)
            local module_cmds="list info enable disable status configure help"
            if [[ ${COMP_CWORD} -eq 2 ]]; then
                COMPREPLY=($(compgen -W "${module_cmds}" -- ${cur}))
            elif [[ ${COMP_CWORD} -eq 3 ]]; then
                COMPREPLY=($(compgen -W "${modules}" -- ${cur}))
            fi
            ;;
        --compliance)
            local compliance_cmds="scan report list frameworks profiles"
            if [[ ${COMP_CWORD} -eq 2 ]]; then
                COMPREPLY=($(compgen -W "${compliance_cmds}" -- ${cur}))
            elif [[ ${COMP_CWORD} -eq 3 ]]; then
                COMPREPLY=($(compgen -W "${frameworks}" -- ${cur}))
            fi
            ;;
        --dashboard)
            local dashboard_cmds="overview security compliance network logs modules help"
            COMPREPLY=($(compgen -W "${dashboard_cmds}" -- ${cur}))
            ;;
        *)
            COMPREPLY=($(compgen -W "${main_opts}" -- ${cur}))
            ;;
    esac
}

# Register completion
complete -F _harden_complete harden.sh
complete -F _harden_complete ./harden.sh

# Completion for common aliases
complete -F _harden_complete harden
complete -F _harden_complete hardening

# Enable completion for sudo usage
complete -F _harden_complete sudo harden.sh
complete -F _harden_complete sudo ./harden.sh
EOF
}

# Install completion script
install_completion() {
    local completion_dir="/etc/bash_completion.d"
    local user_completion_dir="$HOME/.bash_completion.d"
    local script_name="harden-completion.sh"
    
    echo "Installing bash completion for Linux Server Hardening Platform..."
    
    # Try system-wide installation first
    if [[ -w "$completion_dir" ]]; then
        generate_completion_script > "$completion_dir/$script_name"
        echo "✅ Installed system-wide completion: $completion_dir/$script_name"
    else
        # Fall back to user installation
        mkdir -p "$user_completion_dir"
        generate_completion_script > "$user_completion_dir/$script_name"
        echo "✅ Installed user completion: $user_completion_dir/$script_name"
        
        # Add to bashrc if not already there
        local bashrc="$HOME/.bashrc"
        if [[ -f "$bashrc" ]] && ! grep -q "bash_completion.d" "$bashrc"; then
            echo "" >> "$bashrc"
            echo "# Load custom bash completions" >> "$bashrc"
            echo "for completion in ~/.bash_completion.d/*; do" >> "$bashrc"
            echo "    [[ -r \"\$completion\" ]] && source \"\$completion\"" >> "$bashrc"
            echo "done" >> "$bashrc"
            echo "✅ Added completion loading to ~/.bashrc"
        fi
    fi
    
    echo ""
    echo "To enable completion in your current session:"
    echo "  source $completion_dir/$script_name"
    echo "  # or"
    echo "  source $user_completion_dir/$script_name"
    echo ""
    echo "Completion will be automatically available in new shell sessions."
}

# Test completion
test_completion() {
    echo "Testing bash completion..."
    echo ""
    
    # Test basic completion
    echo "Testing main command completion:"
    local test_cases=(
        "harden.sh --"
        "harden.sh --c"
        "harden.sh --m"
        "harden.sh --modules "
        "harden.sh --profile "
        "harden.sh --compliance "
    )
    
    for test_case in "${test_cases[@]}"; do
        echo "  Input: $test_case"
        # This would need actual completion testing in a real shell
        echo "  Result: [completion would appear here]"
        echo ""
    done
    
    echo "Completion test completed."
    echo "For interactive testing, source the completion script and use TAB completion."
}

# Show completion help
show_completion_help() {
    cat << EOF
Bash Completion for Linux Server Hardening Platform

INSTALLATION:
  ./completion.sh install    - Install completion system-wide or for current user
  ./completion.sh generate   - Generate completion script to stdout
  ./completion.sh test       - Test completion functionality

USAGE:
  After installation, use TAB completion with harden.sh:
  
  harden.sh --<TAB>          # Complete main options
  harden.sh --config <TAB>   # Complete config files
  harden.sh --modules <TAB>  # Complete module commands
  harden.sh --profile <TAB>  # Complete profile names
  
FEATURES:
  • Intelligent context-aware completion
  • Module and profile name completion
  • Configuration file path completion
  • Command option completion
  • Subcommand completion
  • Smart suggestions based on usage patterns

COMPLETION CONTEXTS:
  • Main commands and options
  • Module names and subcommands
  • Compliance frameworks and profiles
  • Configuration files (.yaml, .yml)
  • Fleet management operations
  • API server commands
  • Dashboard panels and options

EXAMPLES:
  harden.sh --apply --modules ss<TAB>     → ssh
  harden.sh --profile stand<TAB>         → standard_baseline
  harden.sh --compliance scan ci<TAB>     → cis_ubuntu_22_04
  harden.sh --config configs/cus<TAB>     → configs/custom.yaml

EOF
}

# Main completion script entry point
main() {
    case "${1:-help}" in
        install)
            install_completion
            ;;
        generate)
            generate_completion_script
            ;;
        test)
            test_completion
            ;;
        help|--help|-h)
            show_completion_help
            ;;
        *)
            echo "Usage: $0 {install|generate|test|help}"
            echo "Use '$0 help' for detailed information."
            exit 1
            ;;
    esac
}

# Register the main completion function for interactive use
complete -F _harden_completions harden.sh
complete -F _harden_completions ./harden.sh

# If script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi