#!/bin/bash

# Legacy File Deprecation and Organization Script
# Moves legacy scripts to deprecated directory and creates migration wrappers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the new output functions
source "$PROJECT_ROOT/src/cli/output.sh"

# Initialize output system
init_output_system

print_header "Legacy File Deprecation and Organization"

# Deprecated directory
DEPRECATED_DIR="$PROJECT_ROOT/deprecated"

# List of files to deprecate
declare -A LEGACY_FILES=(
    ["$PROJECT_ROOT/install-packages.sh"]="packages"
    ["$PROJECT_ROOT/auditd-rules/apply-auditd-rules.sh"]="auditd"
    ["$PROJECT_ROOT/sysctl/apply-sysctl-config.sh"]="sysctl"
    ["$PROJECT_ROOT/fail2ban/apply-fail2ban-config.sh"]="fail2ban"
    ["$PROJECT_ROOT/password-policy/apply-pam-pwquality.sh"]="pam"
    ["$PROJECT_ROOT/banner/apply-banner.sh"]="banner"
)

# Create deprecation wrapper
create_deprecation_wrapper() {
    local original_script="$1"
    local module_name="$2"
    local script_name=$(basename "$original_script")
    
    cat > "$original_script" << EOF
#!/bin/bash

# DEPRECATED SCRIPT - $(basename "$original_script")
# This script has been replaced by the modular hardening system

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo ""
echo -e "\${RED}======================================\${NC}"
echo -e "\${RED}        DEPRECATION NOTICE\${NC}"
echo -e "\${RED}======================================\${NC}"
echo ""
echo -e "\${YELLOW}This script ($script_name) is DEPRECATED.\${NC}"
echo ""
echo -e "\${CYAN}Please use the new modular hardening system:\${NC}"
echo ""
echo -e "  \${GREEN}# Apply specific module:\${NC}"
echo -e "  ./harden.sh -m $module_name"
echo ""
echo -e "  \${GREEN}# Apply all modules:\${NC}"
echo -e "  ./harden.sh -a"
echo ""
echo -e "  \${GREEN}# Interactive mode:\${NC}"
echo -e "  ./harden.sh -i"
echo ""
echo -e "  \${GREEN}# Get help:\${NC}"
echo -e "  ./harden.sh --help"
echo ""
echo -e "\${YELLOW}Benefits of the new system:\${NC}"
echo -e "  • Unified YAML configuration"
echo -e "  • Consistent error handling"
echo -e "  • Better validation and dry-run support"
echo -e "  • Modular architecture"
echo -e "  • Comprehensive logging"
echo ""
echo -e "\${RED}This wrapper will be removed in a future version.\${NC}"
echo ""

# Check if new system is available
if [[ -f "\$PROJECT_ROOT/harden.sh" ]]; then
    echo -e "\${CYAN}Auto-executing new system...\${NC}"
    echo ""
    exec "\$PROJECT_ROOT/harden.sh" -m "$module_name" "\$@"
else
    echo -e "\${RED}ERROR: New hardening system not found.\${NC}"
    echo -e "Please ensure harden.sh is available in the project root."
    exit 1
fi
EOF
    
    chmod +x "$original_script"
    print_success "Created deprecation wrapper for $(basename "$original_script")"
}

# Move original files to deprecated directory
move_to_deprecated() {
    local original_script="$1"
    local module_name="$2"
    
    # Create deprecated directory if it doesn't exist
    mkdir -p "$DEPRECATED_DIR"
    
    # Create module-specific backup if original exists
    if [[ -f "${original_script}.backup."* ]]; then
        local backup_file=$(ls "${original_script}.backup."* | head -1)
        local deprecated_backup="$DEPRECATED_DIR/$(basename "$backup_file")"
        
        mv "$backup_file" "$deprecated_backup"
        print_verbose "Moved backup to deprecated: $(basename "$deprecated_backup")"
    fi
    
    # Create README in deprecated directory
    if [[ ! -f "$DEPRECATED_DIR/README.md" ]]; then
        create_deprecated_readme
    fi
}

# Create README for deprecated directory
create_deprecated_readme() {
    cat > "$DEPRECATED_DIR/README.md" << 'EOF'
# Deprecated Legacy Scripts

This directory contains legacy scripts that have been replaced by the new modular hardening system.

## Migration Information

These scripts have been superseded by the new modular architecture:

- **install-packages.sh** → `./harden.sh -m packages`
- **auditd-rules/apply-auditd-rules.sh** → `./harden.sh -m auditd`
- **sysctl/apply-sysctl-config.sh** → `./harden.sh -m sysctl`
- **fail2ban/apply-fail2ban-config.sh** → `./harden.sh -m fail2ban`
- **password-policy/apply-pam-pwquality.sh** → `./harden.sh -m pam`
- **banner/apply-banner.sh** → `./harden.sh -m banner`

## New System Benefits

- **Unified Configuration**: Single YAML file for all settings
- **Consistent Error Handling**: Standardized output and error reporting
- **Validation Support**: Built-in configuration validation
- **Dry Run Mode**: Preview changes before applying
- **Modular Architecture**: Clean separation of concerns
- **Better Logging**: Comprehensive execution tracking

## Usage Examples

```bash
# Apply all hardening modules
./harden.sh -a

# Apply specific module
./harden.sh -m ssh

# Interactive mode
./harden.sh -i

# Dry run (preview only)
./harden.sh -a --dry-run

# Validate configuration
./harden.sh --validate

# Get help
./harden.sh --help
```

## Configuration

All configuration is now centralized in `configs/default.yaml`. You can also create custom configuration files:

```bash
# Use custom configuration
./harden.sh -c configs/my-config.yaml -a
```

## Migration Timeline

- **Phase 1**: Legacy scripts converted to deprecation wrappers ✓
- **Phase 2**: Full module implementation ✓
- **Phase 3**: Documentation updates ✓
- **Phase 4**: Legacy script removal (future release)

## Support

If you encounter issues with the new system, please:

1. Check the documentation in `docs/`
2. Use `--verbose` mode for detailed output
3. Try `--validate` to check configuration
4. Report issues in the project repository

The legacy scripts in this directory are kept for reference only and should not be used directly.
EOF
    
    print_success "Created deprecated directory README"
}

# Create directory migration notice
create_directory_notices() {
    local directories=(
        "auditd-rules"
        "sysctl"
        "fail2ban"
        "password-policy"
        "banner"
    )
    
    for dir in "${directories[@]}"; do
        if [[ -d "$PROJECT_ROOT/$dir" ]]; then
            cat > "$PROJECT_ROOT/$dir/DEPRECATED_README.md" << EOF
# DEPRECATED: $dir

This directory contains legacy hardening scripts that have been replaced by the modular system.

## Migration

Use the new modular system instead:

\`\`\`bash
# Old way (deprecated):
./$dir/apply-*.sh

# New way:
./harden.sh -m ${dir%%-*}  # Apply specific module
./harden.sh -a            # Apply all modules
\`\`\`

## Benefits

- YAML-based configuration
- Better error handling
- Validation support  
- Dry-run capability
- Unified logging

## Configuration

Module settings are now in \`configs/default.yaml\`:

\`\`\`yaml
modules:
  ${dir%%-*}:
    # Module-specific settings here
\`\`\`

See the main project README for migration instructions.
EOF
            print_verbose "Created deprecation notice for $dir/"
        fi
    done
}

# Update main project structure
update_project_structure() {
    print_section "Updating Project Structure"
    
    # Create configs/examples if it doesn't exist
    mkdir -p "$PROJECT_ROOT/configs/examples"
    
    # Create example configurations
    if [[ ! -f "$PROJECT_ROOT/configs/examples/minimal.yaml" ]]; then
        cat > "$PROJECT_ROOT/configs/examples/minimal.yaml" << 'EOF'
# Minimal Linux Hardening Configuration
# Basic security hardening with minimal changes

dry_run: false
verbose: false
backup_configs: true

enabled_modules:
  - ssh
  - ufw

modules:
  ssh:
    permit_root_login: false
    password_authentication: false
    
  ufw:
    default_incoming: deny
    default_outgoing: allow
    allowed_ports:
      - 22/tcp
EOF
        print_success "Created minimal configuration example"
    fi
    
    if [[ ! -f "$PROJECT_ROOT/configs/examples/comprehensive.yaml" ]]; then
        cat > "$PROJECT_ROOT/configs/examples/comprehensive.yaml" << 'EOF'
# Comprehensive Linux Hardening Configuration
# Full security hardening with all modules enabled

dry_run: false
verbose: true
backup_configs: true
log_level: info

enabled_modules:
  - ssh
  - ufw
  - sysctl
  - fail2ban
  - auditd
  - packages
  - pam
  - banner

modules:
  ssh:
    permit_root_login: false
    password_authentication: false
    x11_forwarding: false
    max_auth_tries: 3
    
  ufw:
    default_incoming: deny
    default_outgoing: allow
    allowed_ports:
      - 22/tcp
      - 80/tcp
      - 443/tcp
      
  sysctl:
    randomize_va_space: 2
    log_martians: 1
    tcp_syncookies: 1
    
  fail2ban:
    ban_time: 3600
    max_retry: 3
    
  auditd:
    monitor_identity_files: true
    monitor_ssh_config: true
    make_immutable: true
    
  packages:
    enable_auto_reboot: true
    
  pam:
    min_length: 12
    min_class: 3
EOF
        print_success "Created comprehensive configuration example"
    fi
}

# Main execution
main() {
    print_section "Starting Legacy File Deprecation"
    
    local processed=0
    local total=${#LEGACY_FILES[@]}
    
    # Create deprecated directory
    mkdir -p "$DEPRECATED_DIR"
    
    # Process each legacy file
    for original_script in "${!LEGACY_FILES[@]}"; do
        local module_name="${LEGACY_FILES[$original_script]}"
        
        print_progress $((processed + 1)) $total "Processing $(basename "$original_script")"
        
        if [[ -f "$original_script" ]]; then
            # Move original to deprecated and create wrapper
            move_to_deprecated "$original_script" "$module_name"
            create_deprecation_wrapper "$original_script" "$module_name"
            
            ((processed++))
        else
            print_warning "Script not found: $original_script"
        fi
    done
    
    # Create directory notices
    create_directory_notices
    
    # Update project structure
    update_project_structure
    
    print_success "Processed $processed legacy scripts"
    
    print_section "Next Steps"
    print_info "1. Test the new modular system with: ./harden.sh --validate"
    print_info "2. Run a dry-run: ./harden.sh -a --dry-run"
    print_info "3. Apply hardening: ./harden.sh -a"
    print_info "4. Review deprecated directory: $DEPRECATED_DIR"
}

# Validation function
validate_deprecation() {
    print_section "Validating Deprecation"
    
    local all_good=true
    
    # Check that wrappers exist and are executable
    for original_script in "${!LEGACY_FILES[@]}"; do
        if [[ -f "$original_script" && -x "$original_script" ]]; then
            print_success "✓ $(basename "$original_script") - Wrapper created and executable"
        else
            print_error "✗ $(basename "$original_script") - Wrapper missing or not executable"
            all_good=false
        fi
    done
    
    # Check deprecated directory structure
    if [[ -d "$DEPRECATED_DIR" && -f "$DEPRECATED_DIR/README.md" ]]; then
        print_success "✓ Deprecated directory structure created"
    else
        print_error "✗ Deprecated directory structure incomplete"
        all_good=false
    fi
    
    # Check new configuration examples
    if [[ -f "$PROJECT_ROOT/configs/examples/minimal.yaml" ]]; then
        print_success "✓ Configuration examples created"
    else
        print_warning "? Configuration examples may need manual review"
    fi
    
    if [[ "$all_good" == "true" ]]; then
        print_success "Deprecation validation passed"
        return 0
    else
        print_error "Deprecation validation failed"
        return 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
    validate_deprecation
    show_execution_summary
fi