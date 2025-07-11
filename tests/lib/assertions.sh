#!/bin/bash

# Test Assertions Library
# Provides assertion functions for testing framework

# Source test utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_utils.sh"

# Assertion counters
ASSERTIONS_PASSED=0
ASSERTIONS_FAILED=0
ASSERTIONS_TOTAL=0

# Core assertion function
_assert() {
    local assertion_type="$1"
    local expected="$2"
    local actual="$3"
    local message="$4"
    
    ((ASSERTIONS_TOTAL++))
    
    local result=false
    case "$assertion_type" in
        "equals")
            [[ "$actual" == "$expected" ]] && result=true
            ;;
        "not_equals")
            [[ "$actual" != "$expected" ]] && result=true
            ;;
        "contains")
            [[ "$actual" == *"$expected"* ]] && result=true
            ;;
        "not_contains")
            [[ "$actual" != *"$expected"* ]] && result=true
            ;;
        "matches")
            [[ "$actual" =~ $expected ]] && result=true
            ;;
        "not_matches")
            [[ ! "$actual" =~ $expected ]] && result=true
            ;;
        "true")
            [[ "$expected" == "true" ]] && result=true
            ;;
        "false")
            [[ "$expected" == "false" ]] && result=true
            ;;
        "success")
            [[ "$expected" -eq 0 ]] && result=true
            ;;
        "failure")
            [[ "$expected" -ne 0 ]] && result=true
            ;;
        "exists")
            [[ -e "$expected" ]] && result=true
            ;;
        "not_exists")
            [[ ! -e "$expected" ]] && result=true
            ;;
        "file_exists")
            [[ -f "$expected" ]] && result=true
            ;;
        "dir_exists")
            [[ -d "$expected" ]] && result=true
            ;;
        "executable")
            [[ -x "$expected" ]] && result=true
            ;;
        "empty")
            [[ -z "$expected" ]] && result=true
            ;;
        "not_empty")
            [[ -n "$expected" ]] && result=true
            ;;
    esac
    
    if [[ "$result" == "true" ]]; then
        ((ASSERTIONS_PASSED++))
        echo -e "${TEST_GREEN}✓${TEST_NC} ${message:-$assertion_type assertion passed}"
        test_log "PASS" "${message:-$assertion_type assertion passed}"
        return 0
    else
        ((ASSERTIONS_FAILED++))
        echo -e "${TEST_RED}✗${TEST_NC} ${message:-$assertion_type assertion failed}"
        echo -e "  Expected: ${TEST_YELLOW}$expected${TEST_NC}"
        echo -e "  Actual:   ${TEST_YELLOW}$actual${TEST_NC}"
        test_log "FAIL" "${message:-$assertion_type assertion failed} - Expected: $expected, Actual: $actual"
        return 1
    fi
}

# String assertions
assert_equals() {
    _assert "equals" "$1" "$2" "$3"
}

assert_not_equals() {
    _assert "not_equals" "$1" "$2" "$3"
}

assert_contains() {
    _assert "contains" "$1" "$2" "$3"
}

assert_not_contains() {
    _assert "not_contains" "$1" "$2" "$3"
}

assert_matches() {
    _assert "matches" "$1" "$2" "$3"
}

assert_not_matches() {
    _assert "not_matches" "$1" "$2" "$3"
}

assert_empty() {
    _assert "empty" "$1" "" "$2"
}

assert_not_empty() {
    _assert "not_empty" "$1" "" "$2"
}

# Boolean assertions
assert_true() {
    local condition="$1"
    local message="$2"
    
    if eval "$condition"; then
        _assert "true" "true" "true" "$message"
    else
        _assert "true" "true" "false" "$message"
    fi
}

assert_false() {
    local condition="$1"
    local message="$2"
    
    if eval "$condition"; then
        _assert "false" "false" "true" "$message"
    else
        _assert "false" "false" "false" "$message"
    fi
}

# Exit code assertions
assert_success() {
    local exit_code="$1"
    local message="$2"
    _assert "success" "$exit_code" "" "$message"
}

assert_failure() {
    local exit_code="$1"
    local message="$2"
    _assert "failure" "$exit_code" "" "$message"
}

# File system assertions
assert_file_exists() {
    _assert "file_exists" "$1" "" "$2"
}

assert_file_not_exists() {
    _assert "not_exists" "$1" "" "$2"
}

assert_dir_exists() {
    _assert "dir_exists" "$1" "" "$2"
}

assert_dir_not_exists() {
    _assert "not_exists" "$1" "" "$2"
}

assert_executable() {
    _assert "executable" "$1" "" "$2"
}

# Command assertions
assert_command_success() {
    local command="$1"
    local message="$2"
    
    if $command >/dev/null 2>&1; then
        _assert "success" "0" "" "${message:-Command '$command' should succeed}"
    else
        local exit_code=$?
        _assert "success" "$exit_code" "" "${message:-Command '$command' should succeed}"
    fi
}

assert_command_failure() {
    local command="$1"
    local message="$2"
    
    if $command >/dev/null 2>&1; then
        _assert "failure" "0" "" "${message:-Command '$command' should fail}"
    else
        local exit_code=$?
        _assert "failure" "$exit_code" "" "${message:-Command '$command' should fail}"
    fi
}

assert_command_output() {
    local command="$1"
    local expected_output="$2"
    local message="$3"
    
    local actual_output
    actual_output=$($command 2>&1)
    _assert "equals" "$expected_output" "$actual_output" "${message:-Command output assertion}"
}

assert_command_contains() {
    local command="$1"
    local expected_substring="$2"
    local message="$3"
    
    local actual_output
    actual_output=$($command 2>&1)
    _assert "contains" "$expected_substring" "$actual_output" "${message:-Command output contains assertion}"
}

# Service assertions
assert_service_running() {
    local service="$1"
    local message="$2"
    
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        _assert "true" "true" "true" "${message:-Service '$service' should be running}"
    else
        _assert "true" "true" "false" "${message:-Service '$service' should be running}"
    fi
}

assert_service_enabled() {
    local service="$1"
    local message="$2"
    
    if systemctl is-enabled --quiet "$service" 2>/dev/null; then
        _assert "true" "true" "true" "${message:-Service '$service' should be enabled}"
    else
        _assert "true" "true" "false" "${message:-Service '$service' should be enabled}"
    fi
}

# Configuration file assertions
assert_config_contains() {
    local config_file="$1"
    local setting="$2"
    local message="$3"
    
    if [[ -f "$config_file" ]] && grep -q "$setting" "$config_file"; then
        _assert "true" "true" "true" "${message:-Config file '$config_file' should contain '$setting'}"
    else
        _assert "true" "true" "false" "${message:-Config file '$config_file' should contain '$setting'}"
    fi
}

assert_config_value() {
    local config_file="$1"
    local key="$2"
    local expected_value="$3"
    local message="$4"
    
    if [[ ! -f "$config_file" ]]; then
        _assert "equals" "$expected_value" "FILE_NOT_FOUND" "${message:-Config assertion}"
        return
    fi
    
    local actual_value
    actual_value=$(grep "^$key" "$config_file" | cut -d' ' -f2- | xargs)
    _assert "equals" "$expected_value" "$actual_value" "${message:-Config value assertion for '$key'}"
}

# Reset assertion counters
reset_assertions() {
    ASSERTIONS_PASSED=0
    ASSERTIONS_FAILED=0
    ASSERTIONS_TOTAL=0
}

# Get assertion statistics
get_assertion_stats() {
    echo "Assertions: $ASSERTIONS_TOTAL total, $ASSERTIONS_PASSED passed, $ASSERTIONS_FAILED failed"
}

# Print assertion summary
print_assertion_summary() {
    echo
    echo -e "${TEST_CYAN}=== Assertion Summary ===${TEST_NC}"
    get_assertion_stats
    
    if [[ $ASSERTIONS_FAILED -eq 0 ]]; then
        echo -e "${TEST_GREEN}All assertions passed!${TEST_NC}"
        return 0
    else
        echo -e "${TEST_RED}$ASSERTIONS_FAILED assertion(s) failed${TEST_NC}"
        return 1
    fi
}

# Export functions for use in test scripts
export -f _assert assert_equals assert_not_equals assert_contains assert_not_contains
export -f assert_matches assert_not_matches assert_empty assert_not_empty
export -f assert_true assert_false assert_success assert_failure
export -f assert_file_exists assert_file_not_exists assert_dir_exists assert_dir_not_exists
export -f assert_executable assert_command_success assert_command_failure
export -f assert_command_output assert_command_contains
export -f assert_service_running assert_service_enabled
export -f assert_config_contains assert_config_value
export -f reset_assertions get_assertion_stats print_assertion_summary