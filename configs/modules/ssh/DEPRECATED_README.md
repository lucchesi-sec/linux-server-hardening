# DEPRECATED: SSH Configuration Directory

This directory contains legacy SSH hardening scripts that have been replaced by the new modular system.

## Migration Information

The SSH hardening functionality has been migrated to:
- **New Location**: `src/modules/ssh.sh`
- **New Usage**: `./harden.sh -a` (includes SSH module)
- **Configuration**: `configs/default.yaml`

## Legacy Files

- `apply-ssh-config.sh` - **DEPRECATED** - Use `./harden.sh` instead
- `sshd_config` - Template moved to modular configuration system

## Why the Change?

The legacy SSH script had several issues:
- Duplicated 111 lines of code with the new module (189 lines)
- Different error handling and configuration approaches
- Not integrated with the framework's validation system
- Harder to maintain and extend

## Migration Guide

**Before (Legacy)**:
```bash
sudo ./ssh-config/apply-ssh-config.sh
```

**After (New System)**:
```bash
./harden.sh -a                    # Apply all modules including SSH
./harden.sh -i                    # Interactive mode
./harden.sh --validate            # Validate SSH configuration
```

The new system provides:
- ✅ Integrated validation
- ✅ Configuration management
- ✅ Dry-run capability
- ✅ Better error handling
- ✅ Consistent interface

**DO NOT USE THE LEGACY SCRIPTS** - they will be removed in a future version.