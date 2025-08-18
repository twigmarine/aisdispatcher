# AIS Dispatcher NixOS Migration Notes

## Overview
Convert the AIS Dispatcher installation script (`tmp/aishub/install_dispatcher`) into a proper NixOS module/derivation for declarative package management.

## Current Installation Analysis

### What the Script Does
1. **Downloads** `full.tar.bz2` from aishub.net with version verification (MD5)
2. **Creates system user** `ais` with specific groups and permissions `enable-linger`
3. **Extracts archive** 
5. **Sets up web and websocket interface** on port 8080

### Current Source Structure
```
/home/ais/
├── bin/           # Binaries (architecture-specific)
├── etc/           # Configuration files
│   ├── aiscontrol.cfg
│   ├── aisdispatcher.json
│   └── aisdispatcher/
├── htdocs/        # Web interface files
├── lib/           # Architecture-specific libraries
└── update_cache/  # Update mechanism
```

### Dependencies
- `wget` (download)
- `aha` (ANSI HTML adapter for colored console output)
- `systemd-journal` group access (for logs)
- `dialout` group access (for serial devices)

### Binary Distribution

- **Download version 2.2** - Get the specific pinned version
   ```bash
   wget https://www.aishub.net/downloads/dispatcher/packages/2.2/full.tar.bz2
   sha256sum full.tar.bz2  # Calculate hash for derivation
   ```
- **Examine extracted files** - `tmp/aishub/full`
- **Multi-architecture** - Handle arm, aarch64, x86_64 binaries. Only install binaries for target architecture instead of all platforms

- **Auto-update removal**: Removed update functionality (anti-pattern in NixOS)
- **Dynamic linking** - May need FHS environment or specific libraries
- **Proprietary software** - Cannot modify source, must work with provided binaries

## NixOS Migration Strategy

### Package Derivation: `pkgs/aisdispatcher/default.nix`
- Uses `fetchurl` with SHA256 hash verification
- Implements efficient architecture-specific installation
- Uses `autoPatchelfHook` for binary compatibility
- Removes auto-update functionality

### NixOS Module: `service/aisdispatcher.nix`
- Comprehensive service configuration with options for ports, interfaces, users
- Added websocket port configuration (default 8081)
- Read-only computed options for integration (`htdocsPath`, `package`)
- Proper systemd service with environment variables and security settings
- Configuration management with template copying and ownership
- Firewall integration

### Documentation: `service/aisdispatcher.md`
- Usage examples including basic and advanced configurations
- Caddy reverse proxy integration examples
- Serial device and TCP/UDP server mode documentation
- Service management commands


### Phase 1: Package Derivation
Create a derivation that:
- [x] **Fetch source** - Use `fetchurl` to download and verify the tarball
- [x] **Create package structure** - Extract and organize files properly
- [x] **Handle architecture** - Support x86_64, aarch64, arm binaries/libraries
- [x] **Install files** - Place in appropriate FHS locations

### Phase 2: NixOS Module
Create a module that:
- [x] **User management** - Create `ais` user with proper groups
- [x] **Service definition** - SystemD service for the dispatcher
- [x] **Configuration options** - Expose key settings (port, interface, etc.)
- [x] **Data directory** - Manage persistent data and logs
- [x] **Networking** - Firewall rules for web interface

### Phase 3: Integration
- [x] **Module testing** - Verify functionality matches original install
- [ ] **Documentation** - Usage examples and configuration options
- [ ] **Security review** - Ensure proper permissions and isolation

## Implementation Details

### Package Structure
```nix
{ stdenv, fetchurl, lib, ... }:

stdenv.mkDerivation rec {
  pname = "aisdispatcher";
  version = "2.2";  # Pin to specific version for reproducibility
  
  src = fetchurl {
    url = "https://www.aishub.net/downloads/dispatcher/packages/${version}/full.tar.bz2";
    sha256 = "1b7cf1df37e17d0b17d08830a08f6d5fb8faa0755bc4f327bbaf5993f8fc9a9a";  # Use sha256 instead of MD5 for better security
    # Need to fetch and calculate hash for version 2.2
  };
  
  # Architecture selection logic
  # Installation phases
  # File organization
}
```

### Network Configuration
- **Web Interface**: Default port 8080 (configured as 8079 in iris)
- **Websocket**: Default port 8081
- **Protocols**: HTTP redirects to HTTPS on port 8043
- Verify service: `systemctl status aisdispatcher`
- Test web interface: `https://iris:8079` and websocket `https://iris:8081`

### Module Configuration
```nix
{
  services.ais-dispatcher = {
    enable = true;
    port = 8079;
    interface = "0.0.0.0";
    user = "ais";
    group = "ais";
    dataDir = "/var/lib/aisdispatcher";
    # Serial device permissions
    # Journal access
  };
}
```

## Challenges & Considerations

### User Session Management
- **Systemd user sessions** - Handle `loginctl enable-linger` equivalent
- **Home directory** - `/var/lib/aisdispatcher`
- **Permissions** - Serial device access, journal reading

### Update Mechanism
- **Built-in updater** - Original package has update cache mechanism
- **NixOS updates** - Handle through normal nixpkgs update process
- **Configuration migration** - Preserve settings across updates

### Web Interface
- **Static files** - Serve htdocs content
- **Port binding** - Configurable listen address/port
- **Reverse proxy** - Integration with existing Caddy setup

## Current Status

### Completed ✅
- Package derivation with multi-architecture support
- NixOS module with comprehensive options
- Documentation with usage examples
- **Tested binary execution** - Verified basic functionality in NixOS environment

### Pending Testing 🔄
- Dry-build validation on target system
- Actual service deployment and startup
- Web interface accessibility verification

## Next Steps

- **Develop systemd service** - Doesn't seem possible. aiscontrol assuming working as user service.
- **Integration testing** - Verify against original functionality
- Limit `ais` user access to single USB device.

## Questions to Resolve

- [ ] What are the exact library dependencies?
- [ ] How does the update mechanism work?
- [ ] Can we use systemd system services instead of user sessions? Not that I know of.
- [ ] What configuration options are most important to expose?
- [ ] Can we run the binaries in a pure NixOS environment?
