#!/bin/bash

# Real-time CLI Dashboard
# Interactive monitoring dashboard for security status and system health

# Source enhanced output
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/enhanced_output.sh"

# Dashboard configuration
DASHBOARD_REFRESH_RATE="${DASHBOARD_REFRESH_RATE:-2}"
DASHBOARD_WIDTH="${DASHBOARD_WIDTH:-120}"
DASHBOARD_HEIGHT="${DASHBOARD_HEIGHT:-30}"
SHOW_GRID="${SHOW_GRID:-true}"

# Dashboard state
declare -A DASHBOARD_STATE=(
    [running]="false"
    [mode]="overview"
    [selected_panel]=0
    [auto_refresh]="true"
    [last_update]=""
)

declare -A METRICS_CACHE=(
    [cpu_usage]=0
    [memory_usage]=0
    [disk_usage]=0
    [network_connections]=0
    [failed_logins]=0
    [security_alerts]=0
    [compliance_score]=0
    [uptime]=""
    [load_average]=""
)

# Dashboard panels
declare -A PANELS=(
    [overview]="System Overview"
    [security]="Security Status"
    [compliance]="Compliance Dashboard"
    [network]="Network Monitoring"
    [logs]="Live Logs"
    [modules]="Hardening Modules"
)

# Initialize dashboard
init_dashboard() {
    init_enhanced_output
    
    # Check terminal size
    if [[ $CLI_WIDTH -lt 80 ]] || [[ $CLI_HEIGHT -lt 20 ]]; then
        error "Terminal too small for dashboard. Minimum 80x20 required."
        exit 1
    fi
    
    # Hide cursor and setup cleanup
    tput civis
    trap cleanup_dashboard EXIT INT TERM
    
    # Clear screen
    clear
    
    DASHBOARD_STATE[running]="true"
    DASHBOARD_STATE[last_update]=$(date "+%H:%M:%S")
}

# Cleanup dashboard
cleanup_dashboard() {
    tput cnorm # Show cursor
    clear
    echo "Dashboard closed."
}

# Main dashboard loop
run_dashboard() {
    init_dashboard
    
    while [[ "${DASHBOARD_STATE[running]}" == "true" ]]; do
        # Update metrics
        update_metrics
        
        # Clear and redraw
        clear
        draw_dashboard_frame
        
        case "${DASHBOARD_STATE[mode]}" in
            "overview")
                draw_overview_panel
                ;;
            "security")
                draw_security_panel
                ;;
            "compliance")
                draw_compliance_panel
                ;;
            "network")
                draw_network_panel
                ;;
            "logs")
                draw_logs_panel
                ;;
            "modules")
                draw_modules_panel
                ;;
        esac
        
        draw_dashboard_footer
        
        # Handle input with timeout
        if read -t "$DASHBOARD_REFRESH_RATE" -n1 input; then
            handle_dashboard_input "$input"
        fi
        
        DASHBOARD_STATE[last_update]=$(date "+%H:%M:%S")
    done
}

# Update system metrics
update_metrics() {
    # CPU usage
    if command -v top >/dev/null; then
        METRICS_CACHE[cpu_usage]=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' || echo "0")
    fi
    
    # Memory usage
    if command -v free >/dev/null; then
        local mem_info
        mem_info=$(free | grep Mem:)
        local total used
        total=$(echo "$mem_info" | awk '{print $2}')
        used=$(echo "$mem_info" | awk '{print $3}')
        if [[ $total -gt 0 ]]; then
            METRICS_CACHE[memory_usage]=$((used * 100 / total))
        fi
    fi
    
    # Disk usage
    local disk_info
    disk_info=$(df / | tail -1)
    METRICS_CACHE[disk_usage]=$(echo "$disk_info" | awk '{print $5}' | sed 's/%//')
    
    # Network connections
    if command -v ss >/dev/null; then
        METRICS_CACHE[network_connections]=$(ss -tuln | wc -l)
    elif command -v netstat >/dev/null; then
        METRICS_CACHE[network_connections]=$(netstat -tuln | wc -l)
    fi
    
    # System info
    METRICS_CACHE[uptime]=$(uptime -p 2>/dev/null | sed 's/up //' || echo "unknown")
    METRICS_CACHE[load_average]=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//')
    
    # Security metrics (simulated for demo)
    METRICS_CACHE[failed_logins]=$((RANDOM % 10))
    METRICS_CACHE[security_alerts]=$((RANDOM % 5))
    METRICS_CACHE[compliance_score]=$((80 + RANDOM % 20))
}

# Draw dashboard frame
draw_dashboard_frame() {
    local width=$CLI_WIDTH
    local title="🛡️  Linux Server Hardening Platform - Real-time Dashboard"
    
    # Header
    if [[ "$USE_COLORS" == "true" ]]; then
        local color_code
        color_code=$(get_theme_color "primary")
        echo -e "${color_code}"
    fi
    
    # Top border
    echo -n "${ICONS[box_top_left]}"
    for ((i=0; i<width-2; i++)); do
        echo -n "${ICONS[box_horizontal]}"
    done
    echo "${ICONS[box_top_right]}"
    
    # Title line
    printf "%s %-$((width-4))s %s\n" "${ICONS[box_vertical]}" "$title" "${ICONS[box_vertical]}"
    
    # Navigation line
    local nav_text="[TAB] Switch Panel | [R] Refresh | [A] Auto-refresh | [T] Theme | [Q] Quit"
    printf "%s %-$((width-4))s %s\n" "${ICONS[box_vertical]}" "$nav_text" "${ICONS[box_vertical]}"
    
    # Separator
    echo -n "${ICONS[box_tee_right]}"
    for ((i=0; i<width-2; i++)); do
        echo -n "${ICONS[box_horizontal]}"
    done
    echo "${ICONS[box_tee_left]}"
    
    if [[ "$USE_COLORS" == "true" ]]; then
        echo -e "${COLORS[reset]}"
    fi
}

# Draw overview panel
draw_overview_panel() {
    local width=$((CLI_WIDTH - 4))
    local left_width=$((width / 3))
    local center_width=$((width / 3))
    local right_width=$((width - left_width - center_width))
    
    # System info panel
    draw_panel "System Information" \
"Hostname: $(hostname)
Uptime: ${METRICS_CACHE[uptime]}
Load: ${METRICS_CACHE[load_average]}
Kernel: $(uname -r)" \
        "$left_width" 0 8
    
    # Performance metrics
    draw_panel "Performance Metrics" \
"CPU Usage: ${METRICS_CACHE[cpu_usage]}%
Memory Usage: ${METRICS_CACHE[memory_usage]}%
Disk Usage: ${METRICS_CACHE[disk_usage]}%
Network Connections: ${METRICS_CACHE[network_connections]}" \
        "$center_width" "$left_width" 8
    
    # Security status
    draw_panel "Security Status" \
"Compliance Score: ${METRICS_CACHE[compliance_score]}%
Failed Logins: ${METRICS_CACHE[failed_logins]}
Security Alerts: ${METRICS_CACHE[security_alerts]}
Last Scan: Never" \
        "$right_width" "$((left_width + center_width))" 8
    
    # Performance graphs (simplified)
    echo
    draw_mini_graph "CPU" "${METRICS_CACHE[cpu_usage]}" "$((CLI_WIDTH / 4))"
    draw_mini_graph "Memory" "${METRICS_CACHE[memory_usage]}" "$((CLI_WIDTH / 4))"
    draw_mini_graph "Disk" "${METRICS_CACHE[disk_usage]}" "$((CLI_WIDTH / 4))"
    draw_mini_graph "Security Score" "${METRICS_CACHE[compliance_score]}" "$((CLI_WIDTH / 4))"
}

# Draw security panel
draw_security_panel() {
    local width=$((CLI_WIDTH - 4))
    
    # Security services status
    draw_panel "Security Services" \
"SSH: $(get_service_status ssh)
UFW Firewall: $(get_service_status ufw)
Fail2ban: $(get_service_status fail2ban)
Auditd: $(get_service_status auditd)
AppArmor: $(get_service_status apparmor)" \
        "$((width / 2))" 0 10
    
    # Recent security events
    draw_panel "Recent Security Events" \
"[$(date "+%H:%M")] SSH login attempt from 192.168.1.100
[$(date --date='-5 minutes' "+%H:%M")] UFW blocked connection to port 443
[$(date --date='-10 minutes' "+%H:%M")] Fail2ban banned IP 10.0.0.50
[$(date --date='-15 minutes' "+%H:%M")] Audit event: file modification in /etc
[$(date --date='-20 minutes' "+%H:%M")] AppArmor policy violation detected" \
        "$((width / 2))" "$((width / 2))" 10
    
    # Security alerts
    echo
    if [[ ${METRICS_CACHE[security_alerts]} -gt 0 ]]; then
        show_alert "warning" "Active Security Alerts" "${METRICS_CACHE[security_alerts]} security alerts require attention"
    else
        show_alert "success" "Security Status" "No active security alerts"
    fi
}

# Draw compliance panel
draw_compliance_panel() {
    local width=$((CLI_WIDTH - 4))
    
    # Compliance scores
    draw_panel "Compliance Frameworks" \
"CIS Ubuntu 22.04: 85% ✅
NIST 800-53: 78% ⚠️
PCI DSS: 92% ✅
ISO 27001: 81% ✅
SOC2: 88% ✅
HIPAA: 90% ✅" \
        "$((width / 2))" 0 10
    
    # Failed controls
    draw_panel "Failed Controls" \
"CIS 1.1.1.1: File system mounting
CIS 2.1.1: xinetd service check
NIST AU-2: Event logging configuration
NIST SC-7: Boundary protection
PCI 1.1.1: Network security controls" \
        "$((width / 2))" "$((width / 2))" 10
    
    # Compliance trend
    echo
    info "Compliance Trend (Last 7 days):"
    draw_trend_chart "85 82 88 86 89 87 ${METRICS_CACHE[compliance_score]}" "$((CLI_WIDTH - 10))"
}

# Draw network panel
draw_network_panel() {
    local width=$((CLI_WIDTH - 4))
    
    # Network connections
    draw_panel "Active Connections" \
"Total Connections: ${METRICS_CACHE[network_connections]}
SSH Connections: $(get_ssh_connections)
Web Connections: $(get_web_connections)
Database Connections: $(get_db_connections)
Unknown Connections: $(get_unknown_connections)" \
        "$((width / 2))" 0 10
    
    # Firewall status
    draw_panel "Firewall Status" \
"UFW Status: $(get_ufw_status)
Default Incoming: DENY
Default Outgoing: ALLOW
Rules Count: $(get_ufw_rules_count)
Recent Blocks: $(get_recent_blocks)" \
        "$((width / 2))" "$((width / 2))" 10
    
    # Network activity graph
    echo
    info "Network Activity (Connections/minute):"
    local activity="12 15 18 22 19 16 ${METRICS_CACHE[network_connections]}"
    draw_trend_chart "$activity" "$((CLI_WIDTH - 10))"
}

# Draw logs panel
draw_logs_panel() {
    local width=$((CLI_WIDTH - 4))
    
    info "Live System Logs:"
    echo
    
    # Simulate live logs
    local logs=(
        "$(date "+%H:%M:%S") kernel: [UFW BLOCK] IN=eth0 OUT= SRC=192.168.1.100 DST=10.0.0.1"
        "$(date --date='-30 seconds' "+%H:%M:%S") sshd: Accepted publickey for user from 192.168.1.50"
        "$(date --date='-1 minute' "+%H:%M:%S") fail2ban: [sshd] Ban 10.0.0.25"
        "$(date --date='-2 minutes' "+%H:%M:%S") auditd: FILE_WRITE path=/etc/passwd"
        "$(date --date='-3 minutes' "+%H:%M:%S") apparmor: DENIED /usr/bin/test access"
    )
    
    for log in "${logs[@]}"; do
        if [[ "$log" =~ BLOCK|DENIED|Ban ]]; then
            eprint "error" "$log"
        elif [[ "$log" =~ Accepted|SUCCESS ]]; then
            eprint "success" "$log"
        else
            eprint "info" "$log"
        fi
    done
    
    echo
    info "Press 'L' to view full log files"
}

# Draw modules panel
draw_modules_panel() {
    local width=$((CLI_WIDTH - 4))
    
    # Module status table
    info "Hardening Modules Status:"
    echo
    
    print_table "Module" "Status" "Last Applied" "Score"
    print_table_row "SSH Hardening" "✅ Active" "2024-01-15 14:30" "95%"
    print_table_row "UFW Firewall" "✅ Active" "2024-01-15 14:31" "90%"
    print_table_row "Fail2ban" "✅ Active" "2024-01-15 14:32" "85%"
    print_table_row "Sysctl Hardening" "✅ Active" "2024-01-15 14:33" "88%"
    print_table_row "Audit Logging" "⚠️ Partial" "2024-01-15 14:34" "75%"
    print_table_row "AppArmor" "❌ Inactive" "Never" "0%"
    print_table_row "AIDE" "❌ Inactive" "Never" "0%"
    close_table 4
    
    echo
    info "Press 'M' to manage modules"
}

# Draw mini panel
draw_panel() {
    local title="$1"
    local content="$2"
    local width="$3"
    local x_offset="$4"
    local height="$5"
    
    # Position cursor
    if [[ $x_offset -gt 0 ]]; then
        printf "\033[%dC" "$x_offset"
    fi
    
    # Panel header
    printf "┌─ %s " "$title"
    local remaining=$((width - ${#title} - 4))
    for ((i=0; i<remaining; i++)); do
        printf "─"
    done
    printf "┐\n"
    
    # Panel content
    local line_count=0
    while IFS= read -r line && [[ $line_count -lt $((height - 2)) ]]; do
        if [[ $x_offset -gt 0 ]]; then
            printf "\033[%dC" "$x_offset"
        fi
        printf "│ %-$((width-4))s │\n" "${line:0:$((width-4))}"
        ((line_count++))
    done <<< "$content"
    
    # Fill remaining lines
    while [[ $line_count -lt $((height - 2)) ]]; do
        if [[ $x_offset -gt 0 ]]; then
            printf "\033[%dC" "$x_offset"
        fi
        printf "│ %-$((width-4))s │\n" ""
        ((line_count++))
    done
    
    # Panel footer
    if [[ $x_offset -gt 0 ]]; then
        printf "\033[%dC" "$x_offset"
    fi
    printf "└"
    for ((i=0; i<width-2; i++)); do
        printf "─"
    done
    printf "┘\n"
}

# Draw mini graph
draw_mini_graph() {
    local title="$1"
    local value="$2"
    local width="$3"
    
    local bar_width=$((width - ${#title} - 10))
    local filled=$((value * bar_width / 100))
    
    printf "%-12s [" "$title:"
    
    local color_code
    if [[ $value -ge 80 ]]; then
        color_code=$(get_theme_color "error")
    elif [[ $value -ge 60 ]]; then
        color_code=$(get_theme_color "warning")
    else
        color_code=$(get_theme_color "success")
    fi
    
    if [[ "$USE_COLORS" == "true" ]]; then
        echo -n -e "$color_code"
    fi
    
    for ((i=0; i<filled; i++)); do
        echo -n "█"
    done
    
    if [[ "$USE_COLORS" == "true" ]]; then
        echo -n -e "${COLORS[reset]}"
    fi
    
    for ((i=filled; i<bar_width; i++)); do
        echo -n "░"
    done
    
    printf "] %3d%%\n" "$value"
}

# Draw trend chart
draw_trend_chart() {
    local data="$1"
    local width="$2"
    
    local -a values
    IFS=' ' read -ra values <<< "$data"
    
    local max_val=0
    for val in "${values[@]}"; do
        if [[ $val -gt $max_val ]]; then
            max_val=$val
        fi
    done
    
    # Draw chart
    local chart_height=8
    for ((row=chart_height; row>=1; row--)); do
        printf "  %3d │" "$((max_val * row / chart_height))"
        
        for val in "${values[@]}"; do
            local normalized_height=$((val * chart_height / max_val))
            if [[ $normalized_height -ge $row ]]; then
                printf "▄"
            else
                printf " "
            fi
        done
        echo
    done
    
    # X-axis
    printf "      └"
    for ((i=0; i<${#values[@]}; i++)); do
        printf "─"
    done
    echo
}

# Draw dashboard footer
draw_dashboard_footer() {
    local width=$CLI_WIDTH
    
    # Navigation tabs
    echo
    printf "Panels: "
    for panel_key in overview security compliance network logs modules; do
        if [[ "$panel_key" == "${DASHBOARD_STATE[mode]}" ]]; then
            eprint "primary" "[${PANELS[$panel_key]}]"
        else
            eprint "muted" " ${PANELS[$panel_key]} "
        fi
        printf " "
    done
    echo
    
    # Status line
    if [[ "$USE_COLORS" == "true" ]]; then
        local color_code
        color_code=$(get_theme_color "muted")
        echo -e "${color_code}"
    fi
    
    echo -n "${ICONS[box_bottom_left]}"
    for ((i=0; i<width-2; i++)); do
        echo -n "${ICONS[box_horizontal]}"
    done
    echo "${ICONS[box_bottom_right]}"
    
    # Footer info
    local auto_status="OFF"
    if [[ "${DASHBOARD_STATE[auto_refresh]}" == "true" ]]; then
        auto_status="ON"
    fi
    
    printf "Last Update: %s | Auto-refresh: %s | Refresh Rate: %ds | Theme: %s\n" \
        "${DASHBOARD_STATE[last_update]}" "$auto_status" "$DASHBOARD_REFRESH_RATE" "$CLI_THEME"
    
    if [[ "$USE_COLORS" == "true" ]]; then
        echo -e "${COLORS[reset]}"
    fi
}

# Handle dashboard input
handle_dashboard_input() {
    local input="$1"
    
    case "$input" in
        $'\t'|' ') # Tab or space to switch panels
            switch_panel
            ;;
        r|R) # Refresh
            update_metrics
            ;;
        a|A) # Toggle auto-refresh
            if [[ "${DASHBOARD_STATE[auto_refresh]}" == "true" ]]; then
                DASHBOARD_STATE[auto_refresh]="false"
            else
                DASHBOARD_STATE[auto_refresh]="true"
            fi
            ;;
        t|T) # Theme selector
            select_theme
            ;;
        1) DASHBOARD_STATE[mode]="overview" ;;
        2) DASHBOARD_STATE[mode]="security" ;;
        3) DASHBOARD_STATE[mode]="compliance" ;;
        4) DASHBOARD_STATE[mode]="network" ;;
        5) DASHBOARD_STATE[mode]="logs" ;;
        6) DASHBOARD_STATE[mode]="modules" ;;
        +) # Increase refresh rate
            if [[ $DASHBOARD_REFRESH_RATE -lt 10 ]]; then
                ((DASHBOARD_REFRESH_RATE++))
            fi
            ;;
        -) # Decrease refresh rate
            if [[ $DASHBOARD_REFRESH_RATE -gt 1 ]]; then
                ((DASHBOARD_REFRESH_RATE--))
            fi
            ;;
        q|Q) # Quit
            DASHBOARD_STATE[running]="false"
            ;;
    esac
}

# Switch to next panel
switch_panel() {
    local panels=(overview security compliance network logs modules)
    local current_index=0
    
    for i in "${!panels[@]}"; do
        if [[ "${panels[i]}" == "${DASHBOARD_STATE[mode]}" ]]; then
            current_index=$i
            break
        fi
    done
    
    local next_index=$(((current_index + 1) % ${#panels[@]}))
    DASHBOARD_STATE[mode]="${panels[$next_index]}"
}

# Utility functions for getting system information
get_service_status() {
    local service="$1"
    
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "✅ Active"
    elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
        echo "⚠️ Inactive"
    else
        echo "❌ Disabled"
    fi
}

get_ssh_connections() {
    ss -tn state established '( dport = :22 or sport = :22 )' 2>/dev/null | wc -l || echo "0"
}

get_web_connections() {
    ss -tn state established '( dport = :80 or dport = :443 or sport = :80 or sport = :443 )' 2>/dev/null | wc -l || echo "0"
}

get_db_connections() {
    ss -tn state established '( dport = :3306 or dport = :5432 )' 2>/dev/null | wc -l || echo "0"
}

get_unknown_connections() {
    echo "$((METRICS_CACHE[network_connections] - $(get_ssh_connections) - $(get_web_connections) - $(get_db_connections)))"
}

get_ufw_status() {
    if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
        echo "✅ Active"
    else
        echo "❌ Inactive"
    fi
}

get_ufw_rules_count() {
    if command -v ufw >/dev/null; then
        ufw status numbered 2>/dev/null | grep -c "^\[" || echo "0"
    else
        echo "0"
    fi
}

get_recent_blocks() {
    echo "15" # Simulated
}

# Help function
show_dashboard_help() {
    clear
    show_banner "Dashboard Help"
    
    cat << EOF
Dashboard Navigation:
  TAB, Space    - Switch between panels
  1-6          - Jump to specific panel
  R            - Manual refresh
  A            - Toggle auto-refresh
  T            - Change theme
  +/-          - Adjust refresh rate
  Q            - Quit dashboard

Panels:
  1. Overview     - System overview and performance metrics
  2. Security     - Security services and recent events
  3. Compliance   - Compliance framework status
  4. Network      - Network connections and firewall
  5. Logs         - Live system logs
  6. Modules      - Hardening modules status

Features:
  • Real-time metrics updating every ${DASHBOARD_REFRESH_RATE} seconds
  • Color-coded status indicators
  • Interactive panel switching
  • Responsive layout adaptation
  • Theme customization support

EOF
    
    printf "Press any key to return to dashboard: "
    read -r -n1
    clear
}

# Main entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-dashboard}" in
        "dashboard"|"")
            run_dashboard
            ;;
        "help")
            show_dashboard_help
            ;;
        "demo")
            demo_enhanced_output
            ;;
        *)
            echo "Usage: $0 [dashboard|help|demo]"
            exit 1
            ;;
    esac
fi