#!/usr/bin/env bash

# Linux Server Hardening Test Runner
# Comprehensive testing framework for modular hardening system

set -euo pipefail

# Test framework configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_DIR="$SCRIPT_DIR"

# Test environment configuration
TEST_CONFIG_DIR="$TESTS_DIR/configs"
TEST_RESULTS_DIR="$TESTS_DIR/results"
TEST_LOGS_DIR="$TESTS_DIR/logs"
MOCK_ROOT_DIR="$TESTS_DIR/mock_system"

# Test statistics
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
TESTS_WARNINGS=0

# Test suite categories
UNIT_TESTS_DIR="$TESTS_DIR/unit"
INTEGRATION_TESTS_DIR="$TESTS_DIR/integration"
SECURITY_TESTS_DIR="$TESTS_DIR/security"
PERFORMANCE_TESTS_DIR="$TESTS_DIR/performance"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Initialize test framework
init_test_framework() {
    echo -e "${BLUE}Initializing Linux Server Hardening Test Framework${NC}"
    echo "=================================================="
    
    # Create test directories
    mkdir -p "$TEST_RESULTS_DIR" "$TEST_LOGS_DIR" "$MOCK_ROOT_DIR"
    mkdir -p "$UNIT_TESTS_DIR" "$INTEGRATION_TESTS_DIR" "$SECURITY_TESTS_DIR" "$PERFORMANCE_TESTS_DIR"
    
    # Initialize test environment
    setup_test_environment
    
    # Source test utilities
    source "$TESTS_DIR/lib/test_utils.sh"
    source "$TESTS_DIR/lib/mock_system.sh"
    source "$TESTS_DIR/lib/assertions.sh"
    
    echo -e "${GREEN}Test framework initialized successfully${NC}"
    echo ""
}

# Setup test environment
setup_test_environment() {
    # Create mock system directories
    mkdir -p "$MOCK_ROOT_DIR/etc/ssh"
    mkdir -p "$MOCK_ROOT_DIR/etc/ufw"
    mkdir -p "$MOCK_ROOT_DIR/etc/fail2ban"
    mkdir -p "$MOCK_ROOT_DIR/etc/audit"
    mkdir -p "$MOCK_ROOT_DIR/etc/security"
    mkdir -p "$MOCK_ROOT_DIR/etc/sysctl.d"
    
    # Create mock system files
    touch "$MOCK_ROOT_DIR/etc/ssh/sshd_config"
    echo "# Mock SSH configuration for testing" > "$MOCK_ROOT_DIR/etc/ssh/sshd_config"
    
    # Set test environment variables
    export TEST_MODE="true"
    export DRY_RUN="true"
    export MOCK_SYSTEM_ROOT="$MOCK_ROOT_DIR"
    export TEST_CONFIG_PATH="$TEST_CONFIG_DIR/test.yaml"
}

# Display usage information
show_help() {
    cat << EOF
Linux Server Hardening Test Runner

USAGE:
    $0 [OPTIONS] [TEST_CATEGORY]

OPTIONS:
    -a, --all           Run all test categories
    -u, --unit          Run unit tests only
    -i, --integration   Run integration tests only
    -s, --security      Run security validation tests only
    -p, --performance   Run performance tests only
    -v, --verbose       Enable verbose test output
    -f, --fast          Skip slow tests (performance benchmarks)
    -c, --coverage      Generate test coverage report
    --mock             Use mock system (default for safety)
    --real-system      Run tests on real system (DANGEROUS - use with caution)
    --parallel         Run tests in parallel where possible
    --junit            Output results in JUnit XML format
    --help             Show this help message

TEST CATEGORIES:
    unit               Module unit tests (functions, validation)
    integration        End-to-end workflow tests
    security           Security compliance validation
    performance        Performance and benchmark tests

EXAMPLES:
    $0 --all                    # Run all test categories
    $0 -u -v                   # Run unit tests with verbose output
    $0 --integration --mock    # Run integration tests in mock environment
    $0 --security --junit      # Run security tests with JUnit output

SAFETY NOTES:
    - Tests run in mock environment by default for safety
    - Use --real-system only in isolated test environments
    - Performance tests may create temporary system load

EOF
}

# Parse command line arguments
parse_args() {
    VERBOSE=false
    FAST_MODE=false
    COVERAGE=false
    USE_MOCK=true
    PARALLEL=false
    JUNIT_OUTPUT=false
    TEST_CATEGORIES=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--all)
                TEST_CATEGORIES=("unit" "integration" "security" "performance")
                shift
                ;;
            -u|--unit)
                TEST_CATEGORIES+=("unit")
                shift
                ;;
            -i|--integration)
                TEST_CATEGORIES+=("integration")
                shift
                ;;
            -s|--security)
                TEST_CATEGORIES+=("security")
                shift
                ;;
            -p|--performance)
                TEST_CATEGORIES+=("performance")
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--fast)
                FAST_MODE=true
                shift
                ;;
            -c|--coverage)
                COVERAGE=true
                shift
                ;;
            --mock)
                USE_MOCK=true
                shift
                ;;
            --real-system)
                USE_MOCK=false
                echo -e "${RED}WARNING: Running tests on real system. This may modify system configuration!${NC}"
                read -p "Are you sure? (yes/no): " confirm
                if [[ "$confirm" != "yes" ]]; then
                    echo "Aborting."
                    exit 1
                fi
                shift
                ;;
            --parallel)
                PARALLEL=true
                shift
                ;;
            --junit)
                JUNIT_OUTPUT=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            unit|integration|security|performance)
                TEST_CATEGORIES+=("$1")
                shift
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
    
    # Default to all tests if none specified
    if [[ ${#TEST_CATEGORIES[@]} -eq 0 ]]; then
        TEST_CATEGORIES=("unit" "integration" "security")
    fi
}

# Run test category
run_test_category() {
    local category="$1"
    local category_dir
    
    case "$category" in
        "unit")
            category_dir="$UNIT_TESTS_DIR"
            echo -e "${CYAN}Running Unit Tests${NC}"
            ;;
        "integration")
            category_dir="$INTEGRATION_TESTS_DIR"
            echo -e "${CYAN}Running Integration Tests${NC}"
            ;;
        "security")
            category_dir="$SECURITY_TESTS_DIR"
            echo -e "${CYAN}Running Security Tests${NC}"
            ;;
        "performance")
            if [[ "$FAST_MODE" == "true" ]]; then
                echo -e "${YELLOW}Skipping performance tests (fast mode)${NC}"
                return 0
            fi
            category_dir="$PERFORMANCE_TESTS_DIR"
            echo -e "${CYAN}Running Performance Tests${NC}"
            ;;
        *)
            echo -e "${RED}Unknown test category: $category${NC}"
            return 1
            ;;
    esac
    
    echo "=================================="
    
    if [[ ! -d "$category_dir" ]]; then
        echo -e "${YELLOW}Test directory not found: $category_dir${NC}"
        return 0
    fi
    
    # Find and run test files
    local test_files=()
    while IFS= read -r -d '' file; do
        test_files+=("$file")
    done < <(find "$category_dir" -name "test_*.sh" -type f -print0)
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No test files found in $category_dir${NC}"
        return 0
    fi
    
    # Run tests
    for test_file in "${test_files[@]}"; do
        run_test_file "$test_file"
    done
    
    echo ""
}

# Run individual test file
run_test_file() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .sh)
    
    echo -e "${WHITE}Running: $test_name${NC}"
    
    # Set test environment
    local test_log="$TEST_LOGS_DIR/${test_name}.log"
    export CURRENT_TEST_NAME="$test_name"
    export CURRENT_TEST_LOG="$test_log"
    
    # Run the test
    local exit_code=0
    if [[ "$VERBOSE" == "true" ]]; then
        bash "$test_file" 2>&1 | tee "$test_log"
        exit_code=${PIPESTATUS[0]}
    else
        bash "$test_file" > "$test_log" 2>&1
        exit_code=$?
    fi
    
    # Update statistics
    ((TESTS_TOTAL++))
    if [[ $exit_code -eq 0 ]]; then
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓ PASSED${NC}"
    elif [[ $exit_code -eq 2 ]]; then
        ((TESTS_SKIPPED++))
        echo -e "  ${YELLOW}○ SKIPPED${NC}"
    else
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗ FAILED${NC}"
        if [[ "$VERBOSE" != "true" ]]; then
            echo "    Log: $test_log"
        fi
    fi
}

# Generate test report
generate_test_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="$TEST_RESULTS_DIR/test_report_$(date '+%Y%m%d_%H%M%S').txt"
    
    echo -e "${BLUE}Generating Test Report${NC}"
    echo "====================="
    
    cat > "$report_file" << EOF
Linux Server Hardening Test Report
Generated: $timestamp

Test Summary:
=============
Total Tests:    $TESTS_TOTAL
Passed:         $TESTS_PASSED
Failed:         $TESTS_FAILED
Skipped:        $TESTS_SKIPPED
Warnings:       $TESTS_WARNINGS

Success Rate:   $(( TESTS_TOTAL > 0 ? (TESTS_PASSED * 100) / TESTS_TOTAL : 0 ))%

Test Categories Run:
==================
$(printf '%s\n' "${TEST_CATEGORIES[@]}")

Environment:
============
Mock System:    $USE_MOCK
Verbose Mode:   $VERBOSE
Fast Mode:      $FAST_MODE
Parallel Mode:  $PARALLEL

EOF
    
    # Add detailed results if available
    if [[ -d "$TEST_LOGS_DIR" ]]; then
        echo "" >> "$report_file"
        echo "Detailed Results:" >> "$report_file"
        echo "=================" >> "$report_file"
        
        for log_file in "$TEST_LOGS_DIR"/*.log; do
            if [[ -f "$log_file" ]]; then
                local test_name=$(basename "$log_file" .log)
                echo "Test: $test_name" >> "$report_file"
                echo "----------------------------------------" >> "$report_file"
                tail -20 "$log_file" >> "$report_file"
                echo "" >> "$report_file"
            fi
        done
    fi
    
    echo "Report saved to: $report_file"
    
    # Display summary
    echo ""
    echo -e "${WHITE}Test Summary:${NC}"
    echo -e "  Total: $TESTS_TOTAL"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
    fi
    if [[ $TESTS_SKIPPED -gt 0 ]]; then
        echo -e "  ${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
    fi
    
    local success_rate=$(( TESTS_TOTAL > 0 ? (TESTS_PASSED * 100) / TESTS_TOTAL : 0 ))
    echo -e "  Success Rate: ${success_rate}%"
}

# Generate JUnit XML output
generate_junit_xml() {
    if [[ "$JUNIT_OUTPUT" != "true" ]]; then
        return 0
    fi
    
    local junit_file="$TEST_RESULTS_DIR/junit_results.xml"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%S)
    
    cat > "$junit_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites tests="$TESTS_TOTAL" failures="$TESTS_FAILED" skipped="$TESTS_SKIPPED" time="0" timestamp="$timestamp">
EOF
    
    for category in "${TEST_CATEGORIES[@]}"; do
        echo "  <testsuite name=\"$category\">" >> "$junit_file"
        # Add individual test cases here if needed
        echo "  </testsuite>" >> "$junit_file"
    done
    
    echo "</testsuites>" >> "$junit_file"
    echo "JUnit XML saved to: $junit_file"
}

# Cleanup test environment
cleanup_test_environment() {
    # Remove temporary files if in mock mode
    if [[ "$USE_MOCK" == "true" ]]; then
        rm -rf "$MOCK_ROOT_DIR/tmp"/* 2>/dev/null || true
    fi
    
    # Clean up old log files (keep last 10 runs)
    if [[ -d "$TEST_LOGS_DIR" ]]; then
        find "$TEST_LOGS_DIR" -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
    fi
}

# Main execution function
main() {
    # Initialize
    init_test_framework
    
    # Parse arguments
    parse_args "$@"
    
    # Display configuration
    echo -e "${BLUE}Test Configuration:${NC}"
    echo "  Categories: ${TEST_CATEGORIES[*]}"
    echo "  Mock System: $USE_MOCK"
    echo "  Verbose: $VERBOSE"
    echo "  Fast Mode: $FAST_MODE"
    echo ""
    
    # Set up environment
    if [[ "$USE_MOCK" == "true" ]]; then
        setup_mock_environment
    fi
    
    # Run test categories
    for category in "${TEST_CATEGORIES[@]}"; do
        run_test_category "$category"
    done
    
    # Generate reports
    generate_test_report
    generate_junit_xml
    
    # Cleanup
    cleanup_test_environment
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi