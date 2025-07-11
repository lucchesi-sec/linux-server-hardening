#!/bin/bash

# AWS EC2 Test Environment Manager
# Provisions and manages EC2 instances for regression testing

set -euo pipefail

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t2.micro}"
KEY_NAME="${AWS_KEY_NAME:-hardening-test-key}"
SECURITY_GROUP_NAME="hardening-test-sg"
TEST_TAG="hardening-platform-test"

# AMI IDs for different distributions (update as needed)
declare -A DISTRIBUTION_AMIS
DISTRIBUTION_AMIS[ubuntu-20.04]="ami-0c02fb55956c7d316"  # Ubuntu 20.04 LTS
DISTRIBUTION_AMIS[ubuntu-22.04]="ami-08d4ac5b634553e16"  # Ubuntu 22.04 LTS  
DISTRIBUTION_AMIS[debian-11]="ami-00c39f71452c08778"     # Debian 11
DISTRIBUTION_AMIS[centos-8]="ami-0d5eff06f840b45e9"      # CentOS 8
DISTRIBUTION_AMIS[amazonlinux-2]="ami-0abcdef1234567890"  # Amazon Linux 2

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check AWS CLI and credentials
check_aws_prereqs() {
    log_info "Checking AWS prerequisites..."
    
    if ! command -v aws >/dev/null 2>&1; then
        log_error "AWS CLI not found. Please install AWS CLI first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    log_success "AWS prerequisites satisfied"
}

# Create security group if it doesn't exist
setup_security_group() {
    log_info "Setting up security group: $SECURITY_GROUP_NAME"
    
    # Check if security group exists
    if aws ec2 describe-security-groups --group-names "$SECURITY_GROUP_NAME" >/dev/null 2>&1; then
        log_info "Security group $SECURITY_GROUP_NAME already exists"
        return 0
    fi
    
    # Create security group
    SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --group-name "$SECURITY_GROUP_NAME" \
        --description "Security group for hardening platform testing" \
        --query 'GroupId' \
        --output text)
    
    # Add SSH access rule
    aws ec2 authorize-security-group-ingress \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0
    
    log_success "Created security group: $SECURITY_GROUP_ID"
}

# Create or import SSH key pair
setup_ssh_key() {
    log_info "Setting up SSH key pair: $KEY_NAME"
    
    # Check if key pair exists
    if aws ec2 describe-key-pairs --key-names "$KEY_NAME" >/dev/null 2>&1; then
        log_info "Key pair $KEY_NAME already exists"
        return 0
    fi
    
    # Create new key pair
    aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --query 'KeyMaterial' \
        --output text > ~/.ssh/"$KEY_NAME".pem
    
    chmod 600 ~/.ssh/"$KEY_NAME".pem
    
    log_success "Created SSH key pair: ~/.ssh/$KEY_NAME.pem"
}

# Launch EC2 instance for testing
launch_test_instance() {
    local distribution="$1"
    local test_id="${2:-$(date +%s)}"
    
    log_info "Launching test instance for $distribution (Test ID: $test_id)"
    
    # Get AMI ID for distribution
    local ami_id="${DISTRIBUTION_AMIS[$distribution]:-}"
    if [[ -z "$ami_id" ]]; then
        log_error "No AMI configured for distribution: $distribution"
        return 1
    fi
    
    # User data script to prepare instance for testing
    local user_data_script=$(cat << 'EOF'
#!/bin/bash
# Update system
apt-get update -y || yum update -y || true

# Install git and other dependencies
apt-get install -y git curl wget || yum install -y git curl wget || true

# Create test user
useradd -m -s /bin/bash testuser || true
echo "testuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/testuser

# Clone the hardening repository (will be replaced with actual repo)
# git clone https://github.com/your-repo/linux-server-hardening.git /opt/hardening-platform

EOF
    )
    
    # Launch instance
    local instance_id=$(aws ec2 run-instances \
        --image-id "$ami_id" \
        --count 1 \
        --instance-type "$INSTANCE_TYPE" \
        --key-name "$KEY_NAME" \
        --security-groups "$SECURITY_GROUP_NAME" \
        --user-data "$user_data_script" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=hardening-test-$distribution-$test_id},{Key=TestId,Value=$test_id},{Key=Distribution,Value=$distribution},{Key=Purpose,Value=$TEST_TAG}]" \
        --query 'Instances[0].InstanceId' \
        --output text)
    
    if [[ -z "$instance_id" ]]; then
        log_error "Failed to launch instance"
        return 1
    fi
    
    log_success "Launched instance: $instance_id"
    
    # Wait for instance to be running
    log_info "Waiting for instance to be running..."
    aws ec2 wait instance-running --instance-ids "$instance_id"
    
    # Get public IP
    local public_ip=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
    
    log_success "Instance ready: $instance_id ($public_ip)"
    
    # Wait for SSH to be available
    log_info "Waiting for SSH to be available..."
    local ssh_ready=false
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if ssh -i ~/.ssh/"$KEY_NAME".pem -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@"$public_ip" "echo 'SSH Ready'" >/dev/null 2>&1; then
            ssh_ready=true
            break
        fi
        ((attempt++))
        sleep 10
    done
    
    if [[ "$ssh_ready" == "false" ]]; then
        log_error "SSH not available after $((max_attempts * 10)) seconds"
        return 1
    fi
    
    log_success "SSH connection ready"
    
    # Store instance info for later use
    echo "$instance_id,$public_ip,$distribution,$test_id" >> /tmp/test-instances.csv
    
    echo "$instance_id"
}

# Copy test files to instance
setup_test_environment() {
    local instance_id="$1"
    local public_ip="$2"
    
    log_info "Setting up test environment on instance $instance_id"
    
    # Copy hardening platform code
    scp -i ~/.ssh/"$KEY_NAME".pem -r -o StrictHostKeyChecking=no \
        "$(dirname "$(dirname "$(realpath "$0")")")" \
        ubuntu@"$public_ip":/home/ubuntu/hardening-platform/
    
    # Copy test framework
    scp -i ~/.ssh/"$KEY_NAME".pem -r -o StrictHostKeyChecking=no \
        "$(dirname "$(realpath "$0")")" \
        ubuntu@"$public_ip":/home/ubuntu/test-framework/
    
    # Make scripts executable
    ssh -i ~/.ssh/"$KEY_NAME".pem -o StrictHostKeyChecking=no ubuntu@"$public_ip" \
        "chmod +x /home/ubuntu/hardening-platform/*.sh /home/ubuntu/hardening-platform/*/*.sh /home/ubuntu/test-framework/*.sh"
    
    log_success "Test environment setup complete"
}

# Run regression tests on instance
run_regression_tests() {
    local instance_id="$1"
    local public_ip="$2"
    local test_type="${3:-all}"
    
    log_info "Running regression tests on instance $instance_id (Type: $test_type)"
    
    # Create test execution script
    local test_script=$(cat << 'EOF'
#!/bin/bash
set -euo pipefail

cd /home/ubuntu/hardening-platform

# Run existing script baseline test
echo "=== Running existing script baseline test ==="
sudo ./apply-all.sh

# Capture baseline state
echo "=== Capturing baseline system state ==="
./check-hardening.sh > /tmp/baseline-results.txt

# Test new modular system (when implemented)
echo "=== Testing new modular system ==="
# sudo ./harden.sh -a  # Will be implemented

# Validate results
echo "=== Validating results ==="
./check-hardening.sh > /tmp/new-results.txt

# Compare results
echo "=== Comparing baseline vs new results ==="
diff /tmp/baseline-results.txt /tmp/new-results.txt || echo "Differences found - manual review required"

echo "=== Test execution complete ==="
EOF
    )
    
    # Execute tests remotely
    ssh -i ~/.ssh/"$KEY_NAME".pem -o StrictHostKeyChecking=no ubuntu@"$public_ip" \
        "echo '$test_script' > /tmp/run-tests.sh && chmod +x /tmp/run-tests.sh && sudo /tmp/run-tests.sh"
    
    # Retrieve test results
    scp -i ~/.ssh/"$KEY_NAME".pem -o StrictHostKeyChecking=no \
        ubuntu@"$public_ip":/tmp/*-results.txt \
        ./test-results/
    
    log_success "Regression tests completed on instance $instance_id"
}

# Terminate test instances
cleanup_test_instances() {
    local test_id="${1:-}"
    
    log_info "Cleaning up test instances..."
    
    # Get instance IDs to terminate
    local instance_filter="Name=tag:Purpose,Values=$TEST_TAG"
    if [[ -n "$test_id" ]]; then
        instance_filter="$instance_filter Name=tag:TestId,Values=$test_id"
    fi
    
    local instance_ids=$(aws ec2 describe-instances \
        --filters "$instance_filter" "Name=instance-state-name,Values=running,pending" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text)
    
    if [[ -z "$instance_ids" ]]; then
        log_info "No test instances found to cleanup"
        return 0
    fi
    
    # Terminate instances
    aws ec2 terminate-instances --instance-ids $instance_ids >/dev/null
    
    log_success "Terminated instances: $instance_ids"
    
    # Clean up local files
    rm -f /tmp/test-instances.csv
}

# List active test instances
list_test_instances() {
    log_info "Active test instances:"
    
    aws ec2 describe-instances \
        --filters "Name=tag:Purpose,Values=$TEST_TAG" "Name=instance-state-name,Values=running" \
        --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress,Tags[?Key==`Distribution`].Value|[0],Tags[?Key==`TestId`].Value|[0]]' \
        --output table
}

# Main command dispatcher
main() {
    local command="${1:-help}"
    
    case "$command" in
        "setup")
            check_aws_prereqs
            setup_security_group
            setup_ssh_key
            log_success "AWS test environment setup complete"
            ;;
        "launch")
            local distribution="${2:-ubuntu-20.04}"
            local test_id="${3:-$(date +%s)}"
            check_aws_prereqs
            launch_test_instance "$distribution" "$test_id"
            ;;
        "test")
            local instance_id="$2"
            local test_type="${3:-all}"
            
            # Get public IP from instance ID
            local public_ip=$(aws ec2 describe-instances \
                --instance-ids "$instance_id" \
                --query 'Reservations[0].Instances[0].PublicIpAddress' \
                --output text)
            
            setup_test_environment "$instance_id" "$public_ip"
            run_regression_tests "$instance_id" "$public_ip" "$test_type"
            ;;
        "cleanup")
            local test_id="$2"
            cleanup_test_instances "$test_id"
            ;;
        "list")
            list_test_instances
            ;;
        "full-test")
            local distribution="${2:-ubuntu-20.04}"
            local test_id="$(date +%s)"
            
            check_aws_prereqs
            local instance_id=$(launch_test_instance "$distribution" "$test_id")
            
            local public_ip=$(aws ec2 describe-instances \
                --instance-ids "$instance_id" \
                --query 'Reservations[0].Instances[0].PublicIpAddress' \
                --output text)
            
            setup_test_environment "$instance_id" "$public_ip"
            run_regression_tests "$instance_id" "$public_ip" "all"
            
            log_info "Test complete. Instance $instance_id ($public_ip) left running for review."
            log_info "Run '$0 cleanup $test_id' to terminate when done."
            ;;
        "help"|*)
            cat << EOF
AWS EC2 Test Environment Manager

USAGE:
    $0 COMMAND [OPTIONS]

COMMANDS:
    setup                   Setup AWS resources (security group, key pair)
    launch DISTRO [TEST_ID] Launch test instance for distribution
    test INSTANCE_ID [TYPE] Run tests on existing instance
    cleanup [TEST_ID]       Terminate test instances
    list                    List active test instances
    full-test DISTRO        Launch instance, run tests, leave running

DISTRIBUTIONS:
    ubuntu-20.04, ubuntu-22.04, debian-11, centos-8, amazonlinux-2

EXAMPLES:
    $0 setup                           # Initial AWS setup
    $0 launch ubuntu-20.04             # Launch Ubuntu 20.04 instance
    $0 full-test ubuntu-22.04          # Complete test run on Ubuntu 22.04
    $0 cleanup                         # Cleanup all test instances

ENVIRONMENT VARIABLES:
    AWS_REGION      AWS region (default: us-east-1)
    AWS_KEY_NAME    SSH key pair name (default: hardening-test-key)
    INSTANCE_TYPE   EC2 instance type (default: t2.micro)

EOF
            ;;
    esac
}

# Execute main function with all arguments
main "$@"