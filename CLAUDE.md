# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Documentation References

- **@README.md**: User-facing documentation with configuration examples. Project overview, architecture details, and development workflow
- **@NOTES.md**: Detailed migration notes and implementation decisions

## Architecture Overview

This repository contains a NixOS module and package definition for AIS Dispatcher, a service for collecting and distributing AIS (Automatic Identification System) data from ships. The codebase wraps proprietary binary distributions into a declarative NixOS service.

### Key Components

- **`module.nix`**: Complete NixOS service module with comprehensive configuration options
- **`package.nix`**: Nix derivation that packages the proprietary AIS Dispatcher binaries 

### Architecture Pattern

The module follows the standard NixOS service pattern:
1. **Package derivation** (`package.nix`) - Downloads and packages upstream binaries with multi-architecture support
2. **Service module** (`module.nix`) - Provides declarative configuration options and systemd service management
3. **User documentation** - Complete usage examples and integration patterns

## Development Commands

### Building and Testing
```bash
# Build the package for current system
nix-build -A aisdispatcher

# Build the module (requires NixOS evaluation context)
nixos-rebuild build --flake .

# Test in a VM
nixos-rebuild build-vm --flake .
```

### Validation
```bash
# Check Nix syntax
nix flake check

# Evaluate module options
nix eval .#nixosModules.aisdispatcher.options --json
```

## Key Implementation Details

### Multi-Architecture Support
The package derivation handles three architectures:
- `x86_64-linux` → `x86_64` binaries/libraries
- `aarch64-linux` → `armv8_a72` binaries, `aarch64` libraries  
- `armv7l-linux` → `arm1176` binaries, `arm` libraries

### Service Architecture
- **System user**: `ais` with specific group memberships for serial/journal access
- **Data directory**: `/var/lib/aisdispatcher` with persistent configuration
- **User systemd services**: Uses systemd user sessions for the dispatcher processes
- **Dual interfaces**: Separate HTTP (port 8080) and WebSocket (port 8081) servers

### Configuration Management
The module generates configuration files dynamically from NixOS options:
- `aiscontrol.cfg` - Main service configuration
- Copies default configurations on first run
- Preserves user modifications across service restarts

### Security Considerations
- Dedicated system user with minimal privileges
- Optional firewall integration
- Serial device access limited to specified groups
- No auto-update mechanism (handled by NixOS package management)

## Common Tasks

### Adding New Configuration Options
1. Add option definition in `module.nix` options section
2. Reference option in `aiscontrolConfig` template
3. Update documentation in `README.md`
4. Test with example configuration

### Supporting New Architectures
1. Identify binary/library naming pattern in upstream package
2. Add architecture mapping to `archConfig` in `package.nix`
3. Test package build on target architecture

### Debugging Service Issues
- Inspect user services: `sudo -u ais systemctl --user status`
- Verify configuration: Check files in `/var/lib/aisdispatcher/`
