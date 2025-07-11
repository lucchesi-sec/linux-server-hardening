#!/bin/bash

# Mock System Library
# Provides safe mock environment for testing without modifying real system

# Mock system configuration
MOCK_SYSTEM_ROOT="${MOCK_SYSTEM_ROOT:-${TESTS_DIR}/mock_system}"
MOCK_BIN_DIR="$MOCK_SYSTEM_ROOT/bin"
MOCK_ETC_DIR="$MOCK_SYSTEM_ROOT/etc"
MOCK_VAR_DIR="$MOCK_SYSTEM_ROOT/var"
MOCK_TMP_DIR="$MOCK_SYSTEM_ROOT/tmp"

# Mock command tracking
MOCK_COMMANDS_LOG="$MOCK_TMP_DIR/mock_commands.log"
MOCK_COMMAND_RESULTS="$MOCK_TMP_DIR/mock_results"

# Initialize mock system environment
setup_mock_environment() {
    test_info "Setting up mock system environment"
    
    # Create mock directory structure
    mkdir -p "$MOCK_BIN_DIR" "$MOCK_ETC_DIR" "$MOCK_VAR_DIR" "$MOCK_TMP_DIR"
    mkdir -p "$MOCK_COMMAND_RESULTS"
    
    # Create mock system directories
    mkdir -p "$MOCK_ETC_DIR/ssh"
    mkdir -p "$MOCK_ETC_DIR/ufw"
    mkdir -p "$MOCK_ETC_DIR/fail2ban"
    mkdir -p "$MOCK_ETC_DIR/audit"
    mkdir -p "$MOCK_ETC_DIR/security"
    mkdir -p "$MOCK_ETC_DIR/sysctl.d"
    mkdir -p "$MOCK_ETC_DIR/systemd/system"
    mkdir -p "$MOCK_VAR_DIR/log"
    mkdir -p "$MOCK_VAR_DIR/lib"
    
    # Initialize mock command log
    echo "# Mock System Commands Log" > "$MOCK_COMMANDS_LOG"
    echo "# Started: $(date)" >> "$MOCK_COMMANDS_LOG"
    
    # Set up mock system files
    setup_mock_files
    
    # Set up mock commands
    setup_mock_commands
    
    # Export mock environment variables
    export MOCK_SYSTEM_ACTIVE="true"
    export PATH="$MOCK_BIN_DIR:$PATH"
    
    test_info "Mock system environment ready at: $MOCK_SYSTEM_ROOT"
}

# Setup mock system files
setup_mock_files() {
    test_debug "Creating mock system files"
    
    # Mock SSH configuration
    cat > "$MOCK_ETC_DIR/ssh/sshd_config" << 'EOF'
# Mock SSH configuration for testing
Port 22
Protocol 2
PasswordAuthentication yes
PermitRootLogin yes
X11Forwarding yes
LoginGraceTime 120
MaxAuthTries 6
ClientAliveInterval 0
ClientAliveCountMax 3
EOF
    
    # Mock UFW configuration
    mkdir -p "$MOCK_ETC_DIR/ufw/applications.d"
    cat > "$MOCK_ETC_DIR/ufw/ufw.conf" << 'EOF'
# Mock UFW configuration
ENABLED=no
LOGLEVEL=low
IPV6=yes
EOF
    
    # Mock fail2ban configuration
    mkdir -p "$MOCK_ETC_DIR/fail2ban/jail.d"
    cat > "$MOCK_ETC_DIR/fail2ban/jail.conf" << 'EOF'
# Mock fail2ban configuration
[DEFAULT]
bantime = 600
findtime = 600
maxretry = 5

[sshd]
enabled = false
port = ssh
logpath = /var/log/auth.log
EOF
    
    # Mock audit rules
    cat > "$MOCK_ETC_DIR/audit/audit.rules" << 'EOF'
# Mock audit rules
-D
-b 8192
-e 2
EOF
    
    # Mock sysctl configuration
    cat > "$MOCK_ETC_DIR/sysctl.d/99-hardening.conf" << 'EOF'
# Mock sysctl hardening configuration
net.ipv4.ip_forward=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
EOF
    
    # Mock systemd service files
    cat > "$MOCK_ETC_DIR/systemd/system/ssh.service" << 'EOF'
[Unit]
Description=OpenBSD Secure Shell server
[Service]
Type=notify
ExecStart=/usr/sbin/sshd -D
[Install]
WantedBy=multi-user.target
EOF
    
    test_debug "Mock system files created"
}

# Setup mock commands
setup_mock_commands() {
    test_debug "Setting up mock commands"
    
    # Create mock command scripts
    create_mock_command "systemctl"
    create_mock_command "ufw"
    create_mock_command "sshd"
    create_mock_command "service"
    create_mock_command "fail2ban-client"
    create_mock_command "auditctl"
    create_mock_command "apt-get"
    create_mock_command "yum"
    create_mock_command "dnf"
    create_mock_command "pacman"
    create_mock_command "iptables"
    create_mock_command "ip6tables"
    create_mock_command "netstat"
    create_mock_command "ss"
    create_mock_command "ps"
    create_mock_command "pgrep"
    create_mock_command "grep"
    create_mock_command "sed"
    create_mock_command "awk"
    
    # Make mock commands executable
    chmod +x "$MOCK_BIN_DIR"/*
    
    test_debug "Mock commands created"
}

# Create individual mock command
create_mock_command() {
    local cmd_name="$1"
    local mock_script="$MOCK_BIN_DIR/$cmd_name"
    
    cat > "$mock_script" << EOF
#!/bin/bash
# Mock command: $cmd_name

# Log command execution
echo "\$(date '+%Y-%m-%d %H:%M:%S') $cmd_name \$*" >> "$MOCK_COMMANDS_LOG"

# Source mock command behavior if available
if [[ -f "$MOCK_COMMAND_RESULTS/${cmd_name}.sh" ]]; then
    source "$MOCK_COMMAND_RESULTS/${cmd_name}.sh" "\$@"
else
    # Default mock behavior
    mock_${cmd_name}_default "\$@"
fi
EOF
    
    chmod +x "$mock_script"
}

# Default mock command behaviors

# systemctl mock
mock_systemctl_default() {
    case "$1" in
        "is-active")
            case "$2" in
                "ssh"|"sshd")
                    echo "active"
                    return 0
                    ;;
                "ufw")
                    echo "inactive"
                    return 3
                    ;;
                *)
                    echo "inactive"
                    return 3
                    ;;
            esac
            ;;
        "restart"|"start"|"stop"|"enable"|"disable")
            echo "Mock systemctl: $*"
            return 0
            ;;
        "status")
            echo "● $2.service - Mock service"
            echo "   Loaded: loaded"
            echo "   Active: active (running)"
            return 0
            ;;
        *)
            echo "Mock systemctl: $*"
            return 0
            ;;
    esac
}

# UFW mock
mock_ufw_default() {
    case "$1" in
        "status")
            if [[ "$2" == "verbose" ]]; then
                cat << 'EOF'
Status: inactive

Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
EOF
            else
                echo "Status: inactive"
            fi
            return 0
            ;;
        "enable"|"--force")
            echo "Firewall is active and enabled on system startup"
            return 0
            ;;
        "disable")
            echo "Firewall stopped and disabled on system startup"
            return 0
            ;;
        "default")
            echo "Default $2 policy changed to '$3'"
            return 0
            ;;
        "allow"|"deny"|"limit")
            echo "Rule added"
            return 0
            ;;
        "reset")
            echo "Resetting all rules to installed defaults."
            return 0
            ;;
        "logging")
            echo "Logging enabled"
            return 0
            ;;
        *)
            echo "Mock ufw: $*"
            return 0
            ;;
    esac
}

# SSH daemon mock
mock_sshd_default() {
    case "$1" in
        "-t")
            # Test configuration
            if [[ -f "$MOCK_ETC_DIR/ssh/sshd_config" ]]; then
                echo "Configuration file is valid"
                return 0
            else
                echo "Configuration file not found"
                return 1
            fi
            ;;
        "-T")
            # Test configuration and exit
            return 0
            ;;
        *)
            echo "Mock sshd: $*"
            return 0
            ;;
    esac
}

# Package manager mocks
mock_apt-get_default() {
    case "$1" in
        "update")
            echo "Reading package lists..."
            echo "Mock apt-get update completed"
            return 0
            ;;
        "install")
            echo "Reading package lists..."
            echo "Building dependency tree..."
            echo "Mock installing: ${*:2}"
            return 0
            ;;
        *)
            echo "Mock apt-get: $*"
            return 0
            ;;
    esac
}

mock_yum_default() {
    case "$1" in
        "install")
            echo "Mock yum installing: ${*:2}"
            return 0
            ;;
        *)
            echo "Mock yum: $*"
            return 0
            ;;
    esac
}

mock_dnf_default() {
    case "$1" in
        "install")
            echo "Mock dnf installing: ${*:2}"
            return 0
            ;;
        *)
            echo "Mock dnf: $*"
            return 0
            ;;
    esac
}

mock_pacman_default() {
    case "$1" in
        "-S")
            echo "Mock pacman installing: ${*:2}"
            return 0
            ;;
        *)
            echo "Mock pacman: $*"
            return 0
            ;;
    esac
}

# Process mocks
mock_pgrep_default() {
    # Return fake PIDs for common services
    case "$*" in
        *"sshd"*)
            echo "1234"
            return 0
            ;;
        *"fail2ban"*)
            echo "5678"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

mock_ps_default() {
    case "$1" in
        "aux"|"-aux")
            cat << 'EOF'
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.1  19356  1536 ?        Ss   00:00   0:00 /sbin/init
root      1234  0.0  0.2  65496  2048 ?        Ss   00:00   0:00 /usr/sbin/sshd -D
root      5678  0.0  0.1  15344  1024 ?        Ss   00:00   0:00 /usr/bin/fail2ban-server
EOF
            return 0
            ;;
        *)
            echo "Mock ps: $*"
            return 0
            ;;
    esac
}

# Text processing mocks
mock_grep_default() {
    # For testing, just return success for most patterns
    return 0
}

mock_sed_default() {
    # Mock sed just echoes the input
    if [[ -t 0 ]]; then
        echo "Mock sed: $*"
    else
        cat
    fi
    return 0
}

mock_awk_default() {
    # Mock awk just echoes the input
    if [[ -t 0 ]]; then
        echo "Mock awk: $*"
    else
        cat
    fi
    return 0
}

# Network mocks
mock_netstat_default() {
    case "$*" in
        *"-tulpn"*|*"-tlnp"*)
            cat << 'EOF'
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      1234/sshd
tcp        0      0 127.0.0.1:25            0.0.0.0:*               LISTEN      -
tcp6       0      0 :::22                   :::*                    LISTEN      1234/sshd
udp        0      0 0.0.0.0:68              0.0.0.0:*                           -
EOF
            return 0
            ;;
        *)
            echo "Mock netstat: $*"
            return 0
            ;;
    esac
}

mock_ss_default() {
    case "$*" in
        *"-tulpn"*|*"-tlnp"*)
            cat << 'EOF'
Netid  State   Recv-Q  Send-Q   Local Address:Port    Peer Address:Port
tcp    LISTEN  0       128            0.0.0.0:22             0.0.0.0:*      users:(("sshd",pid=1234,fd=3))
tcp    LISTEN  0       128               [::]:22                [::]:*      users:(("sshd",pid=1234,fd=4))
EOF
            return 0
            ;;
        *)
            echo "Mock ss: $*"
            return 0
            ;;
    esac
}

# Mock command result customization
set_mock_command_result() {
    local cmd_name="$1"
    local result_script="$2"
    
    mkdir -p "$MOCK_COMMAND_RESULTS"
    echo "$result_script" > "$MOCK_COMMAND_RESULTS/${cmd_name}.sh"
    test_debug "Set custom mock result for: $cmd_name"
}

# Mock command execution tracking
get_mock_command_calls() {
    local cmd_name="$1"
    if [[ -f "$MOCK_COMMANDS_LOG" ]]; then
        grep " $cmd_name " "$MOCK_COMMANDS_LOG" || true
    fi
}

get_mock_command_count() {
    local cmd_name="$1"
    get_mock_command_calls "$cmd_name" | wc -l
}

# Mock system state management
set_mock_service_state() {
    local service_name="$1"
    local state="$2"  # active, inactive, failed
    
    mkdir -p "$MOCK_VAR_DIR/lib/systemd"
    echo "$state" > "$MOCK_VAR_DIR/lib/systemd/${service_name}.state"
    test_debug "Set mock service state: $service_name = $state"
}

get_mock_service_state() {
    local service_name="$1"
    local state_file="$MOCK_VAR_DIR/lib/systemd/${service_name}.state"
    
    if [[ -f "$state_file" ]]; then
        cat "$state_file"
    else
        echo "inactive"
    fi
}

# Mock firewall state
set_mock_ufw_state() {
    local state="$1"  # active, inactive
    echo "$state" > "$MOCK_VAR_DIR/lib/ufw.state"
    test_debug "Set mock UFW state: $state"
}

get_mock_ufw_state() {
    local state_file="$MOCK_VAR_DIR/lib/ufw.state"
    if [[ -f "$state_file" ]]; then
        cat "$state_file"
    else
        echo "inactive"
    fi
}

# Mock file system operations
mock_file_exists() {
    local file_path="$1"
    # Convert real system paths to mock paths
    local mock_path="${file_path//\/etc\//$MOCK_ETC_DIR/}"
    mock_path="${mock_path//\/var\//$MOCK_VAR_DIR/}"
    
    [[ -f "$mock_path" ]]
}

mock_read_file() {
    local file_path="$1"
    local mock_path="${file_path//\/etc\//$MOCK_ETC_DIR/}"
    mock_path="${mock_path//\/var\//$MOCK_VAR_DIR/}"
    
    if [[ -f "$mock_path" ]]; then
        cat "$mock_path"
    else
        return 1
    fi
}

# Cleanup mock environment
cleanup_mock_environment() {
    test_debug "Cleaning up mock environment"
    
    # Remove mock directories
    if [[ -d "$MOCK_SYSTEM_ROOT" ]] && [[ "$MOCK_SYSTEM_ROOT" =~ mock_system ]]; then
        rm -rf "$MOCK_SYSTEM_ROOT"
    fi
    
    # Restore original PATH
    export PATH="${PATH//$MOCK_BIN_DIR:/}"
    
    # Unset mock variables
    unset MOCK_SYSTEM_ACTIVE
    
    test_debug "Mock environment cleaned up"
}

# Export mock functions
export -f setup_mock_environment setup_mock_files setup_mock_commands
export -f create_mock_command set_mock_command_result
export -f get_mock_command_calls get_mock_command_count
export -f set_mock_service_state get_mock_service_state
export -f set_mock_ufw_state get_mock_ufw_state
export -f mock_file_exists mock_read_file cleanup_mock_environment

# Export default mock functions
export -f mock_systemctl_default mock_ufw_default mock_sshd_default
export -f mock_apt-get_default mock_yum_default mock_dnf_default mock_pacman_default
export -f mock_pgrep_default mock_ps_default mock_grep_default mock_sed_default mock_awk_default
export -f mock_netstat_default mock_ss_default