#!/bin/bash

# Test Utilities Library
# Common functions and utilities for testing framework

# Test output formatting
TEST_RED='\033[0;31m'
TEST_GREEN='\033[0;32m'
TEST_YELLOW='\033[1;33m'
TEST_BLUE='\033[0;34m'
TEST_PURPLE='\033[0;35m'
TEST_CYAN='\033[0;36m'
TEST_WHITE='\033[1;37m'
TEST_NC='\033[0m' # No Color

# Test execution state
CURRENT_TEST_SUITE=""
CURRENT_TEST_CASE=""
TEST_CASE_COUNT=0
TEST_SUITE_PASSED=0
TEST_SUITE_FAILED=0

# Test timing
TEST_START_TIME=""
TEST_END_TIME=""

# Logging functions
test_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "${CURRENT_TEST_LOG:-/dev/null}"
}

test_debug() {
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        test_log "DEBUG" "$*"
    fi
}

test_info() {
    test_log "INFO" "$*"
}

test_warn() {
    test_log "WARN" "$*"
}

test_error() {
    test_log "ERROR" "$*"
}

# Test suite management
begin_test_suite() {
    local suite_name="$1"
    CURRENT_TEST_SUITE="$suite_name"
    TEST_CASE_COUNT=0
    TEST_SUITE_PASSED=0
    TEST_SUITE_FAILED=0
    TEST_START_TIME=$(date +%s)
    
    echo -e "${TEST_CYAN}Starting Test Suite: $suite_name${TEST_NC}"
    test_info "Begin test suite: $suite_name"
}

end_test_suite() {
    TEST_END_TIME=$(date +%s)
    local duration=$((TEST_END_TIME - TEST_START_TIME))
    
    echo -e "${TEST_CYAN}Test Suite Complete: $CURRENT_TEST_SUITE${TEST_NC}"
    echo -e "  Cases: $TEST_CASE_COUNT, Passed: $TEST_SUITE_PASSED, Failed: $TEST_SUITE_FAILED"
    echo -e "  Duration: ${duration}s"
    
    test_info "End test suite: $CURRENT_TEST_SUITE (Duration: ${duration}s, Passed: $TEST_SUITE_PASSED, Failed: $TEST_SUITE_FAILED)"
    
    if [[ $TEST_SUITE_FAILED -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Test case management
begin_test_case() {
    local case_name="$1"
    CURRENT_TEST_CASE="$case_name"
    ((TEST_CASE_COUNT++))
    
    echo -e "${TEST_WHITE}  Test Case $TEST_CASE_COUNT: $case_name${TEST_NC}"
    test_info "Begin test case: $case_name"
}

pass_test_case() {
    ((TEST_SUITE_PASSED++))
    echo -e "    ${TEST_GREEN}✓ PASSED${TEST_NC}"
    test_info "Test case passed: $CURRENT_TEST_CASE"
}

fail_test_case() {
    local reason="$1"
    ((TEST_SUITE_FAILED++))
    echo -e "    ${TEST_RED}✗ FAILED${TEST_NC}"
    if [[ -n "$reason" ]]; then
        echo -e "      Reason: $reason"
    fi
    test_error "Test case failed: $CURRENT_TEST_CASE - $reason"
}

skip_test_case() {
    local reason="$1"
    echo -e "    ${TEST_YELLOW}○ SKIPPED${TEST_NC}"
    if [[ -n "$reason" ]]; then
        echo -e "      Reason: $reason"
    fi
    test_info "Test case skipped: $CURRENT_TEST_CASE - $reason"
}

# File and directory utilities
create_temp_file() {
    local prefix="${1:-test}"
    local temp_file=$(mktemp "${TMPDIR:-/tmp}/${prefix}.XXXXXX")
    echo "$temp_file"
}

create_temp_dir() {
    local prefix="${1:-test}"
    local temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/${prefix}.XXXXXX")
    echo "$temp_dir"
}

cleanup_temp_files() {
    # Clean up temporary files created during testing
    find "${TMPDIR:-/tmp}" -name "test.*" -mtime +1 -delete 2>/dev/null || true
}

# Configuration utilities
create_test_config() {
    local config_file="$1"
    local config_content="$2"
    
    mkdir -p "$(dirname "$config_file")"
    cat > "$config_file" << EOF
# Test Configuration
# Generated for testing purposes

$config_content
EOF
    echo "$config_file"
}

load_test_config() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        source "$config_file"
        test_debug "Loaded test config: $config_file"
    else
        test_error "Test config not found: $config_file"
        return 1
    fi
}

# Process and service utilities
is_process_running() {
    local process_name="$1"
    if pgrep -f "$process_name" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

wait_for_process() {
    local process_name="$1"
    local timeout="${2:-30}"
    local count=0
    
    while [[ $count -lt $timeout ]]; do
        if is_process_running "$process_name"; then
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    return 1
}

# Network utilities
is_port_open() {
    local host="${1:-localhost}"
    local port="$2"
    local timeout="${3:-5}"
    
    if timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

wait_for_port() {
    local host="${1:-localhost}"
    local port="$2"
    local timeout="${3:-30}"
    local count=0
    
    while [[ $count -lt $timeout ]]; do
        if is_port_open "$host" "$port" 1; then
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    return 1
}

# System utilities
backup_file() {
    local file_path="$1"
    local backup_path="${file_path}.test_backup.$(date +%s)"
    
    if [[ -f "$file_path" ]]; then
        cp "$file_path" "$backup_path"
        echo "$backup_path"
    fi
}

restore_file() {
    local backup_path="$1"
    local original_path="${backup_path%.test_backup.*}"
    
    if [[ -f "$backup_path" ]]; then
        mv "$backup_path" "$original_path"
        test_debug "Restored file: $original_path"
    fi
}

# Command execution utilities
run_command() {
    local cmd="$1"
    local expected_exit_code="${2:-0}"
    local output_file="${3:-}"
    
    test_debug "Running command: $cmd"
    
    local exit_code=0
    if [[ -n "$output_file" ]]; then
        eval "$cmd" > "$output_file" 2>&1
        exit_code=$?
    else
        eval "$cmd" >/dev/null 2>&1
        exit_code=$?
    fi
    
    if [[ $exit_code -eq $expected_exit_code ]]; then
        test_debug "Command succeeded (exit code: $exit_code)"
        return 0
    else
        test_debug "Command failed (exit code: $exit_code, expected: $expected_exit_code)"
        return 1
    fi
}

run_command_with_output() {
    local cmd="$1"
    local output_var="$2"
    local error_var="${3:-}"
    
    test_debug "Running command with output capture: $cmd"
    
    local temp_out=$(create_temp_file "cmd_out")
    local temp_err=$(create_temp_file "cmd_err")
    
    local exit_code=0
    eval "$cmd" > "$temp_out" 2> "$temp_err"
    exit_code=$?
    
    # Store output in variables
    eval "$output_var=\"\$(cat \"$temp_out\")\""
    if [[ -n "$error_var" ]]; then
        eval "$error_var=\"\$(cat \"$temp_err\")\""
    fi
    
    # Cleanup
    rm -f "$temp_out" "$temp_err"
    
    return $exit_code
}

# Security testing utilities
check_file_permissions() {
    local file_path="$1"
    local expected_permissions="$2"
    
    if [[ ! -e "$file_path" ]]; then
        test_error "File does not exist: $file_path"
        return 1
    fi
    
    local actual_permissions=$(stat -c "%a" "$file_path" 2>/dev/null || stat -f "%A" "$file_path" 2>/dev/null)
    
    if [[ "$actual_permissions" == "$expected_permissions" ]]; then
        test_debug "File permissions correct: $file_path ($actual_permissions)"
        return 0
    else
        test_error "File permissions incorrect: $file_path (actual: $actual_permissions, expected: $expected_permissions)"
        return 1
    fi
}

check_file_owner() {
    local file_path="$1"
    local expected_owner="$2"
    
    if [[ ! -e "$file_path" ]]; then
        test_error "File does not exist: $file_path"
        return 1
    fi
    
    local actual_owner=$(stat -c "%U" "$file_path" 2>/dev/null || stat -f "%Su" "$file_path" 2>/dev/null)
    
    if [[ "$actual_owner" == "$expected_owner" ]]; then
        test_debug "File owner correct: $file_path ($actual_owner)"
        return 0
    else
        test_error "File owner incorrect: $file_path (actual: $actual_owner, expected: $expected_owner)"
        return 1
    fi
}

# Configuration validation utilities
validate_config_setting() {
    local config_file="$1"
    local setting="$2"
    local expected_value="$3"
    
    if [[ ! -f "$config_file" ]]; then
        test_error "Config file does not exist: $config_file"
        return 1
    fi
    
    local actual_value=$(grep "^${setting}" "$config_file" | cut -d' ' -f2- | xargs)
    
    if [[ "$actual_value" == "$expected_value" ]]; then
        test_debug "Config setting correct: $setting = $actual_value"
        return 0
    else
        test_error "Config setting incorrect: $setting (actual: '$actual_value', expected: '$expected_value')"
        return 1
    fi
}

# Performance utilities
measure_execution_time() {
    local cmd="$1"
    local start_time=$(date +%s.%N)
    
    eval "$cmd"
    local exit_code=$?
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    echo "$duration"
    return $exit_code
}

# Retry utilities
retry_command() {
    local max_attempts="$1"
    local delay="$2"
    shift 2
    local cmd="$*"
    
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        test_debug "Attempt $attempt/$max_attempts: $cmd"
        
        if eval "$cmd"; then
            test_debug "Command succeeded on attempt $attempt"
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            test_debug "Waiting ${delay}s before retry..."
            sleep "$delay"
        fi
        
        ((attempt++))
    done
    
    test_error "Command failed after $max_attempts attempts: $cmd"
    return 1
}

# Cleanup utilities
register_cleanup() {
    local cleanup_cmd="$1"
    echo "$cleanup_cmd" >> "${TMPDIR:-/tmp}/test_cleanup_$$"
}

run_cleanup() {
    local cleanup_file="${TMPDIR:-/tmp}/test_cleanup_$$"
    if [[ -f "$cleanup_file" ]]; then
        while IFS= read -r cleanup_cmd; do
            test_debug "Running cleanup: $cleanup_cmd"
            eval "$cleanup_cmd" 2>/dev/null || true
        done < "$cleanup_file"
        rm -f "$cleanup_file"
    fi
}

# Export all functions
export -f test_log test_debug test_info test_warn test_error
export -f begin_test_suite end_test_suite begin_test_case pass_test_case fail_test_case skip_test_case
export -f create_temp_file create_temp_dir cleanup_temp_files
export -f create_test_config load_test_config
export -f is_process_running wait_for_process is_port_open wait_for_port
export -f backup_file restore_file run_command run_command_with_output
export -f check_file_permissions check_file_owner validate_config_setting
export -f measure_execution_time retry_command register_cleanup run_cleanup