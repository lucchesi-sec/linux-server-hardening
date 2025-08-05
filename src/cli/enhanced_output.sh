#!/bin/bash

# Enhanced CLI Output Module
# Modern CLI with animations, themes, and rich formatting

# Advanced color palette with gradients
declare -A COLORS=(
    # Base colors
    [reset]='\033[0m'
    [bold]='\033[1m'
    [dim]='\033[2m'
    [italic]='\033[3m'
    [underline]='\033[4m'
    [blink]='\033[5m'
    [reverse]='\033[7m'
    [strikethrough]='\033[9m'
    
    # Standard colors
    [black]='\033[30m'
    [red]='\033[31m'
    [green]='\033[32m'
    [yellow]='\033[33m'
    [blue]='\033[34m'
    [magenta]='\033[35m'
    [cyan]='\033[36m'
    [white]='\033[37m'
    
    # Bright colors
    [bright_black]='\033[90m'
    [bright_red]='\033[91m'
    [bright_green]='\033[92m'
    [bright_yellow]='\033[93m'
    [bright_blue]='\033[94m'
    [bright_magenta]='\033[95m'
    [bright_cyan]='\033[96m'
    [bright_white]='\033[97m'
    
    # Background colors
    [bg_black]='\033[40m'
    [bg_red]='\033[41m'
    [bg_green]='\033[42m'
    [bg_yellow]='\033[43m'
    [bg_blue]='\033[44m'
    [bg_magenta]='\033[45m'
    [bg_cyan]='\033[46m'
    [bg_white]='\033[47m'
)

# Theme definitions
declare -A THEMES=(
    [default_primary]="${COLORS[bright_blue]}"
    [default_secondary]="${COLORS[cyan]}"
    [default_success]="${COLORS[bright_green]}"
    [default_warning]="${COLORS[bright_yellow]}"
    [default_error]="${COLORS[bright_red]}"
    [default_info]="${COLORS[bright_cyan]}"
    [default_muted]="${COLORS[bright_black]}"
    
    [dark_primary]="${COLORS[bright_magenta]}"
    [dark_secondary]="${COLORS[magenta]}"
    [dark_success]="${COLORS[green]}"
    [dark_warning]="${COLORS[yellow]}"
    [dark_error]="${COLORS[red]}"
    [dark_info]="${COLORS[cyan]}"
    [dark_muted]="${COLORS[bright_black]}"
    
    [minimal_primary]="${COLORS[white]}"
    [minimal_secondary]="${COLORS[bright_black]}"
    [minimal_success]="${COLORS[white]}"
    [minimal_warning]="${COLORS[white]}"
    [minimal_error]="${COLORS[white]}"
    [minimal_info]="${COLORS[white]}"
    [minimal_muted]="${COLORS[bright_black]}"
)

# Enhanced Unicode icons
declare -A ICONS=(
    # Status icons
    [success]="✅"
    [error]="❌"
    [warning]="⚠️"
    [info]="ℹ️"
    [debug]="🐛"
    [security]="🔒"
    [fire]="🔥"
    [rocket]="🚀"
    [shield]="🛡️"
    [key]="🔑"
    [lock]="🔐"
    [unlock]="🔓"
    
    # Progress icons
    [arrow_right]="➤"
    [arrow_down]="⬇"
    [arrow_up]="⬆"
    [check]="✔"
    [cross]="✖"
    [dot]="●"
    [circle]="○"
    [diamond]="◆"
    [square]="■"
    [triangle]="▲"
    
    # Spinner frames
    [spinner0]="⠋"
    [spinner1]="⠙"
    [spinner2]="⠹"
    [spinner3]="⠸"
    [spinner4]="⠼"
    [spinner5]="⠴"
    [spinner6]="⠦"
    [spinner7]="⠧"
    [spinner8]="⠇"
    [spinner9]="⠏"
    
    # Box drawing
    [box_top_left]="┌"
    [box_top_right]="┐"
    [box_bottom_left]="└"
    [box_bottom_right]="┘"
    [box_horizontal]="─"
    [box_vertical]="│"
    [box_cross]="┼"
    [box_tee_down]="┬"
    [box_tee_up]="┴"
    [box_tee_right]="├"
    [box_tee_left]="┤"
    
    # Progress bars
    [progress_full]="█"
    [progress_three_quarters]="▉"
    [progress_half]="▌"
    [progress_quarter]="▍"
    [progress_empty]="░"
    [progress_light]="▒"
    [progress_medium]="▓"
)

# CLI configuration
CLI_THEME="${CLI_THEME:-default}"
CLI_WIDTH="${CLI_WIDTH:-80}"
CLI_ANIMATIONS="${CLI_ANIMATIONS:-true}"
USE_UNICODE="${USE_UNICODE:-true}"

# Initialize enhanced output system
init_enhanced_output() {
    # Detect terminal capabilities
    if [[ ! -t 1 ]]; then
        USE_COLORS=false
        CLI_ANIMATIONS=false
        USE_UNICODE=false
        return
    fi
    
    # Check color support
    local colors=0
    if command -v tput >/dev/null 2>&1; then
        colors=$(tput colors 2>/dev/null || echo 0)
    fi
    
    if [[ $colors -ge 8 ]]; then
        USE_COLORS=true
    else
        USE_COLORS=false
    fi
    
    # Override if NO_COLOR is set
    if [[ -n "${NO_COLOR:-}" ]]; then
        USE_COLORS=false
    fi
    
    # Check Unicode support
    if [[ "${LANG:-}" =~ UTF-8 ]] || [[ "${LC_ALL:-}" =~ UTF-8 ]]; then
        USE_UNICODE=true
    else
        USE_UNICODE=false
    fi
    
    # Disable animations in CI/non-interactive
    if [[ -n "${CI:-}" ]] || [[ ! -t 0 ]]; then
        CLI_ANIMATIONS=false
    fi
    
    # Set terminal size
    if command -v tput >/dev/null 2>&1; then
        CLI_WIDTH=$(tput cols 2>/dev/null || echo 80)
    fi
}

# Get theme color
get_theme_color() {
    local color_type="$1"
    local theme_key="${CLI_THEME}_${color_type}"
    
    if [[ -n "${THEMES[$theme_key]:-}" ]]; then
        echo "${THEMES[$theme_key]}"
    else
        echo "${THEMES[default_${color_type}]}"
    fi
}

# Enhanced print with styling
eprint() {
    local style="$1"
    local message="$2"
    local icon="${3:-}"
    
    if [[ "$USE_COLORS" != "true" ]]; then
        if [[ -n "$icon" ]]; then
            echo "[$icon] $message"
        else
            echo "$message"
        fi
        return
    fi
    
    local color_code
    color_code=$(get_theme_color "$style")
    
    local output=""
    if [[ -n "$icon" ]]; then
        if [[ "$USE_UNICODE" == "true" ]]; then
            output="${color_code}${ICONS[$icon]} $message${COLORS[reset]}"
        else
            output="${color_code}[$icon] $message${COLORS[reset]}"
        fi
    else
        output="${color_code}$message${COLORS[reset]}"
    fi
    
    echo -e "$output"
}

# Enhanced status messages
success() {
    eprint "success" "$1" "success"
}

error() {
    eprint "error" "$1" "error" >&2
}

warning() {
    eprint "warning" "$1" "warning"
}

info() {
    eprint "info" "$1" "info"
}

debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        eprint "muted" "$1" "debug"
    fi
}

security() {
    eprint "primary" "$1" "security"
}

# Animated spinner
show_spinner() {
    local message="$1"
    local pid="$2"
    
    if [[ "$CLI_ANIMATIONS" != "true" ]] || [[ ! -t 1 ]]; then
        info "$message"
        return
    fi
    
    local spinner_frames=("${ICONS[spinner0]}" "${ICONS[spinner1]}" "${ICONS[spinner2]}" "${ICONS[spinner3]}" 
                          "${ICONS[spinner4]}" "${ICONS[spinner5]}" "${ICONS[spinner6]}" "${ICONS[spinner7]}")
    local i=0
    
    tput civis # Hide cursor
    
    while kill -0 "$pid" 2>/dev/null; do
        local frame="${spinner_frames[$((i % ${#spinner_frames[@]}))]}"
        printf "\r%s %s" "$frame" "$message"
        sleep 0.1
        ((i++))
    done
    
    tput cnorm # Show cursor
    printf "\r%s %s\n" "${ICONS[success]}" "$message"
}

# Enhanced progress bar
show_progress() {
    local current="$1"
    local total="$2"
    local message="$3"
    local width="${4:-40}"
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    local bar=""
    local color_code
    color_code=$(get_theme_color "primary")
    
    # Build progress bar
    if [[ "$USE_UNICODE" == "true" ]]; then
        for ((i=0; i<filled; i++)); do
            bar+="${ICONS[progress_full]}"
        done
        for ((i=0; i<empty; i++)); do
            bar+="${ICONS[progress_empty]}"
        done
    else
        for ((i=0; i<filled; i++)); do
            bar+="="
        done
        for ((i=0; i<empty; i++)); do
            bar+=" "
        done
    fi
    
    if [[ "$USE_COLORS" == "true" ]]; then
        printf "\r${color_code}[%s]${COLORS[reset]} %3d%% %s" "$bar" "$percentage" "$message"
    else
        printf "\r[%s] %3d%% %s" "$bar" "$percentage" "$message"
    fi
    
    if [[ "$current" -eq "$total" ]]; then
        echo
    fi
}

# Multi-line progress with phases
show_phase_progress() {
    local phases=("$@")
    local total=${#phases[@]}
    local current=0
    
    for phase in "${phases[@]}"; do
        ((current++))
        show_progress "$current" "$total" "Phase $current/$total: $phase"
        sleep 0.5 # Simulate work
    done
}

# Enhanced boxes and panels
draw_box() {
    local title="$1"
    local content="$2"
    local width="${3:-$CLI_WIDTH}"
    local style="${4:-primary}"
    
    if [[ "$USE_UNICODE" != "true" ]]; then
        # Fallback to ASCII
        local border=$(printf '%*s' "$((width-2))" | tr ' ' '-')
        echo "+$border+"
        printf "| %-$((width-4))s |\n" "$title"
        echo "+$border+"
        echo "$content" | while IFS= read -r line; do
            printf "| %-$((width-4))s |\n" "$line"
        done
        echo "+$border+"
        return
    fi
    
    local color_code
    color_code=$(get_theme_color "$style")
    
    if [[ "$USE_COLORS" == "true" ]]; then
        echo -e "${color_code}"
    fi
    
    # Top border
    echo -n "${ICONS[box_top_left]}"
    for ((i=0; i<width-2; i++)); do
        echo -n "${ICONS[box_horizontal]}"
    done
    echo "${ICONS[box_top_right]}"
    
    # Title
    if [[ -n "$title" ]]; then
        printf "%s %-$((width-4))s %s\n" "${ICONS[box_vertical]}" "$title" "${ICONS[box_vertical]}"
        
        # Separator
        echo -n "${ICONS[box_tee_right]}"
        for ((i=0; i<width-2; i++)); do
            echo -n "${ICONS[box_horizontal]}"
        done
        echo "${ICONS[box_tee_left]}"
    fi
    
    # Content
    echo "$content" | while IFS= read -r line; do
        printf "%s %-$((width-4))s %s\n" "${ICONS[box_vertical]}" "$line" "${ICONS[box_vertical]}"
    done
    
    # Bottom border
    echo -n "${ICONS[box_bottom_left]}"
    for ((i=0; i<width-2; i++)); do
        echo -n "${ICONS[box_horizontal]}"
    done
    echo "${ICONS[box_bottom_right]}"
    
    if [[ "$USE_COLORS" == "true" ]]; then
        echo -e "${COLORS[reset]}"
    fi
}

# Status panel
show_status_panel() {
    local title="$1"
    shift
    local items=("$@")
    
    local content=""
    for item in "${items[@]}"; do
        content+="$item\n"
    done
    
    draw_box "$title" "$content" "$((CLI_WIDTH / 2))" "info"
}

# Enhanced table with borders
print_table() {
    local -a headers=("$@")
    local col_width=$((CLI_WIDTH / ${#headers[@]} - 3))
    
    if [[ "$USE_UNICODE" != "true" ]]; then
        # ASCII table
        printf "+"
        for header in "${headers[@]}"; do
            printf "%*s+" $((col_width + 1)) | tr ' ' '-'
        done
        echo
        
        printf "|"
        for header in "${headers[@]}"; do
            printf " %-${col_width}s|" "${header:0:$col_width}"
        done
        echo
        
        printf "+"
        for header in "${headers[@]}"; do
            printf "%*s+" $((col_width + 1)) | tr ' ' '-'
        done
        echo
        return
    fi
    
    # Unicode table
    local color_code
    color_code=$(get_theme_color "secondary")
    
    if [[ "$USE_COLORS" == "true" ]]; then
        echo -e "${color_code}"
    fi
    
    # Top border
    echo -n "${ICONS[box_top_left]}"
    for ((i=0; i<${#headers[@]}; i++)); do
        for ((j=0; j<col_width; j++)); do
            echo -n "${ICONS[box_horizontal]}"
        done
        if [[ $i -lt $((${#headers[@]} - 1)) ]]; then
            echo -n "${ICONS[box_tee_down]}"
        fi
    done
    echo "${ICONS[box_top_right]}"
    
    # Headers
    echo -n "${ICONS[box_vertical]}"
    for header in "${headers[@]}"; do
        printf "%-${col_width}s" "${header:0:$col_width}"
        echo -n "${ICONS[box_vertical]}"
    done
    echo
    
    # Separator
    echo -n "${ICONS[box_tee_right]}"
    for ((i=0; i<${#headers[@]}; i++)); do
        for ((j=0; j<col_width; j++)); do
            echo -n "${ICONS[box_horizontal]}"
        done
        if [[ $i -lt $((${#headers[@]} - 1)) ]]; then
            echo -n "${ICONS[box_cross]}"
        fi
    done
    echo "${ICONS[box_tee_left]}"
    
    if [[ "$USE_COLORS" == "true" ]]; then
        echo -e "${COLORS[reset]}"
    fi
}

# Add table row
print_table_row() {
    local -a columns=("$@")
    local col_width=$((CLI_WIDTH / ${#columns[@]} - 3))
    
    if [[ "$USE_UNICODE" != "true" ]]; then
        printf "|"
        for column in "${columns[@]}"; do
            printf " %-${col_width}s|" "${column:0:$col_width}"
        done
        echo
        return
    fi
    
    echo -n "${ICONS[box_vertical]}"
    for column in "${columns[@]}"; do
        printf "%-${col_width}s" "${column:0:$col_width}"
        echo -n "${ICONS[box_vertical]}"
    done
    echo
}

# Close table
close_table() {
    local num_cols="$1"
    local col_width=$((CLI_WIDTH / num_cols - 3))
    
    if [[ "$USE_UNICODE" != "true" ]]; then
        printf "+"
        for ((i=0; i<num_cols; i++)); do
            printf "%*s+" $((col_width + 1)) | tr ' ' '-'
        done
        echo
        return
    fi
    
    local color_code
    color_code=$(get_theme_color "secondary")
    
    if [[ "$USE_COLORS" == "true" ]]; then
        echo -e "${color_code}"
    fi
    
    echo -n "${ICONS[box_bottom_left]}"
    for ((i=0; i<num_cols; i++)); do
        for ((j=0; j<col_width; j++)); do
            echo -n "${ICONS[box_horizontal]}"
        done
        if [[ $i -lt $((num_cols - 1)) ]]; then
            echo -n "${ICONS[box_tee_up]}"
        fi
    done
    echo "${ICONS[box_bottom_right]}"
    
    if [[ "$USE_COLORS" == "true" ]]; then
        echo -e "${COLORS[reset]}"
    fi
}

# Animated typewriter effect
typewriter() {
    local text="$1"
    local delay="${2:-0.03}"
    
    if [[ "$CLI_ANIMATIONS" != "true" ]]; then
        echo "$text"
        return
    fi
    
    local i=0
    while [[ $i -lt ${#text} ]]; do
        echo -n "${text:$i:1}"
        sleep "$delay"
        ((i++))
    done
    echo
}

# Banner with ASCII art
show_banner() {
    local text="$1"
    local style="${2:-primary}"
    
    local color_code
    color_code=$(get_theme_color "$style")
    
    if [[ "$USE_COLORS" == "true" ]]; then
        echo -e "${color_code}"
    fi
    
    cat << 'EOF'
╭─────────────────────────────────────────────────────────────────────╮
│                   🛡️  Linux Server Hardening Platform                │
│                        Security Automation Platform                 │
╰─────────────────────────────────────────────────────────────────────╯
EOF
    
    if [[ "$USE_COLORS" == "true" ]]; then
        echo -e "${COLORS[reset]}"
    fi
}

# Alert boxes
show_alert() {
    local type="$1"
    local title="$2"
    local message="$3"
    
    local icon_key color_style
    
    case "$type" in
        "success")
            icon_key="success"
            color_style="success"
            ;;
        "warning")
            icon_key="warning"
            color_style="warning"
            ;;
        "error")
            icon_key="error"
            color_style="error"
            ;;
        "info")
            icon_key="info"
            color_style="info"
            ;;
        *)
            icon_key="info"
            color_style="info"
            ;;
    esac
    
    local content="${ICONS[$icon_key]} $title\n\n$message"
    draw_box "" "$content" "$CLI_WIDTH" "$color_style"
}

# Set CLI theme
set_theme() {
    local theme="$1"
    
    case "$theme" in
        "default"|"dark"|"minimal")
            CLI_THEME="$theme"
            ;;
        *)
            warning "Unknown theme: $theme. Using default."
            CLI_THEME="default"
            ;;
    esac
}

# Theme selector
select_theme() {
    echo "Available themes:"
    echo "1) Default - Blue/cyan color scheme"
    echo "2) Dark - Purple/magenta color scheme"
    echo "3) Minimal - Black/white color scheme"
    echo
    
    while true; do
        printf "Select theme [1-3]: "
        read -r choice
        
        case "$choice" in
            1)
                set_theme "default"
                break
                ;;
            2)
                set_theme "dark"
                break
                ;;
            3)
                set_theme "minimal"
                break
                ;;
            *)
                warning "Please select 1, 2, or 3"
                ;;
        esac
    done
    
    success "Theme set to: $CLI_THEME"
}

# Demo function to showcase features
demo_enhanced_output() {
    init_enhanced_output
    
    show_banner "Enhanced CLI Demo"
    echo
    
    info "Testing enhanced output features..."
    echo
    
    # Status messages
    success "This is a success message"
    warning "This is a warning message"
    error "This is an error message"
    info "This is an info message"
    security "This is a security message"
    echo
    
    # Progress demo
    info "Progress bar demo:"
    for i in {1..10}; do
        show_progress "$i" "10" "Processing step $i"
        sleep 0.2
    done
    echo
    
    # Table demo
    info "Table demo:"
    print_table "Module" "Status" "Score"
    print_table_row "SSH" "✅ Enabled" "95%"
    print_table_row "UFW" "✅ Active" "88%"
    print_table_row "Audit" "⚠️ Partial" "72%"
    close_table 3
    echo
    
    # Box demo
    info "Box demo:"
    draw_box "System Status" "CPU: 15%\nMemory: 45%\nDisk: 67%" 40 "info"
    echo
    
    # Alert demo
    show_alert "success" "Hardening Complete" "All security modules have been successfully applied."
    echo
    
    success "Enhanced CLI demo completed!"
}

# Initialize on source
init_enhanced_output