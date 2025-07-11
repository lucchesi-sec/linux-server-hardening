#!/bin/bash

# CLI Output Module
# Handles styled output, colors, and formatting

# Color definitions
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r PURPLE='\033[0;35m'
declare -r CYAN='\033[0;36m'
declare -r WHITE='\033[1;37m'
declare -r NC='\033[0m' # No Color

# Icons
declare -r ICON_SUCCESS="✔️"
declare -r ICON_ERROR="❌"
declare -r ICON_WARNING="⚠️"
declare -r ICON_INFO="ℹ️"
declare -r ICON_ARROW="➤"

# Initialize output system
init_output_system() {
    # Check if we should use colors (tty detection)
    if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
        USE_COLORS=true
    else
        USE_COLORS=false
    fi
    
    # Override if NO_COLOR is set
    if [[ -n "${NO_COLOR:-}" ]]; then
        USE_COLORS=false
    fi
}

# Print with color if supported
print_color() {
    local color="$1"
    local message="$2"
    
    if [[ "$USE_COLORS" == "true" ]]; then
        echo -e "${color}${message}${NC}"
    else
        echo "$message"
    fi
}

# Header with border
print_header() {
    local title="$1"
    local width=60
    local border=$(printf '%*s' "$width" | tr ' ' '=')
    
    echo
    print_color "$CYAN" "$border"
    print_color "$WHITE" "$(printf '%*s' $(((width + ${#title}) / 2)) "$title")"
    print_color "$CYAN" "$border"
    echo
}

# Section separator
print_section() {
    local title="$1"
    echo
    print_color "$BLUE" "[$ICON_ARROW] $title"
    print_color "$BLUE" "$(printf '%*s' $((${#title} + 4)) | tr ' ' '-')"
}

# Success message
print_success() {
    local message="$1"
    print_color "$GREEN" "$ICON_SUCCESS $message"
}

# Error message
print_error() {
    local message="$1"
    print_color "$RED" "$ICON_ERROR $message" >&2
}

# Warning message
print_warning() {
    local message="$1"
    print_color "$YELLOW" "$ICON_WARNING $message"
}

# Info message
print_info() {
    local message="$1"
    print_color "$CYAN" "$ICON_INFO $message"
}

# Verbose message (only shown if verbose mode)
print_verbose() {
    local message="$1"
    if [[ "$VERBOSE" == "true" ]]; then
        print_color "$PURPLE" "  $message"
    fi
}

# Progress indicator
print_progress() {
    local current="$1"
    local total="$2"
    local task="$3"
    
    local percentage=$((current * 100 / total))
    local progress_bar=""
    local bar_length=20
    local filled=$((percentage * bar_length / 100))
    
    for ((i=0; i<filled; i++)); do
        progress_bar+="█"
    done
    for ((i=filled; i<bar_length; i++)); do
        progress_bar+="░"
    done
    
    printf "\r[%s] %3d%% %s" "$progress_bar" "$percentage" "$task"
    
    if [[ "$current" -eq "$total" ]]; then
        echo
    fi
}

# Table formatting
print_table_header() {
    local -a headers=("$@")
    local separator=""
    
    printf "| "
    for header in "${headers[@]}"; do
        printf "%-20s | " "$header"
        separator+="$(printf '%*s' 22 | tr ' ' '-')"
    done
    echo
    echo "|$separator"
}

print_table_row() {
    local -a columns=("$@")
    
    printf "| "
    for column in "${columns[@]}"; do
        printf "%-20s | " "$column"
    done
    echo
}

# Summary functions
declare -A EXECUTION_STATS
EXECUTION_STATS[total]=0
EXECUTION_STATS[success]=0
EXECUTION_STATS[warning]=0
EXECUTION_STATS[error]=0

update_stats() {
    local status="$1"
    ((EXECUTION_STATS[total]++))
    ((EXECUTION_STATS[$status]++))
}

show_execution_summary() {
    echo
    print_section "Execution Summary"
    
    print_table_header "Status" "Count" "Percentage"
    
    local total=${EXECUTION_STATS[total]}
    if [[ $total -gt 0 ]]; then
        local success_pct=$((EXECUTION_STATS[success] * 100 / total))
        local warning_pct=$((EXECUTION_STATS[warning] * 100 / total))
        local error_pct=$((EXECUTION_STATS[error] * 100 / total))
        
        print_table_row "Success" "${EXECUTION_STATS[success]}" "${success_pct}%"
        print_table_row "Warning" "${EXECUTION_STATS[warning]}" "${warning_pct}%"
        print_table_row "Error" "${EXECUTION_STATS[error]}" "${error_pct}%"
        print_table_row "Total" "$total" "100%"
    else
        print_info "No operations executed"
    fi
    
    echo
    
    if [[ ${EXECUTION_STATS[error]} -gt 0 ]]; then
        print_error "Execution completed with errors"
        return 1
    elif [[ ${EXECUTION_STATS[warning]} -gt 0 ]]; then
        print_warning "Execution completed with warnings"
        return 0
    else
        print_success "Execution completed successfully"
        return 0
    fi
}