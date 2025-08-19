# AIS Dispatcher NixOS Module

AIS Dispatcher is a service for collecting and distributing AIS (Automatic Identification System) data from ships. This module provides a NixOS service configuration for the AIS Dispatcher.

## Basic Usage

```nix
services.aisdispatcher = {
  enable = true;
  port = 8080;              # Web interface
  websocketPort = 8081;     # Websocket interface  
  interface = "0.0.0.0";    # Bind to all interfaces
  openFirewall = true;      # Open both ports
  sessionTimeout = 1800;    # 30 minutes
};
```

## Configuration Options

### Network Configuration

- `port` (default: 8080) - Port for the web interface
- `websocketPort` (default: 8081) - Port for the websocket interface
- `interface` (default: "127.0.0.1") - Interface to bind the web server to
- `websocketInterface` (default: "127.0.0.1") - Interface to bind the websocket server to
- `openFirewall` (default: false) - Whether to open firewall ports automatically

### Service Configuration

- `user` (default: "ais") - User account for the service
- `group` (default: "ais") - Group account for the service  
- `dataDir` (default: "/var/lib/aisdispatcher") - Data directory
- `sessionTimeout` (default: 900) - Session timeout in seconds
- `serialGroups` (default: ["dialout"]) - Additional groups for serial device access

### Read-only Options

- `package` - The AIS Dispatcher package being used
- `htdocsPath` - Path to static web files (useful for reverse proxy configuration)

## Advanced Examples

### With Caddy Reverse Proxy

```nix
services.aisdispatcher = {
  enable = true;
  interface = "127.0.0.1";  # Only bind to localhost
  openFirewall = false;     # Caddy handles external access
};

services.caddy.virtualHosts."ais.example.com" = {
  extraConfig = ''
    # Handle websocket connections
    handle /realtime* {
      reverse_proxy 127.0.0.1:${toString config.services.aisdispatcher.websocketPort}
    }
    
    # Serve static files directly from Nix store
    handle /static/* {
      root * ${config.services.aisdispatcher.htdocsPath}
      file_server
    }
    
    # Proxy API calls
    handle /api/* {
      reverse_proxy 127.0.0.1:${toString config.services.aisdispatcher.port}
    }
    
    # Default to static files
    handle {
      root * ${config.services.aisdispatcher.htdocsPath}
      try_files {path} /index.html
      file_server
    }
  '';
};
```

### For Serial AIS Receivers

For serial AIS receivers, you have two options for device access:

#### Option 1: Broad Access (Simple)
```nix
services.aisdispatcher = {
  enable = true;
  serialGroups = [ "dialout" "tty" ]; # Add groups for serial access
};
```

#### Option 2: Device-Specific Access (Recommended)
For better security, limit access to only your AIS receiver device. See:
- **[examples/device-specific-access.nix](examples/device-specific-access.nix)** - Complete configuration example
- **[examples/device-discovery.md](examples/device-discovery.md)** - Guide to identify your device and create udev rules

### TCP/UDP Server Mode

If you configure AIS Dispatcher to receive AIS data via TCP/UDP server mode (through the web UI), you'll need to manually open those ports:

```nix
services.aisdispatcher = {
  enable = true;
  openFirewall = true;  # Opens web interface ports
};

# Additional firewall rules for AIS data reception
networking.firewall = {
  allowedTCPPorts = [ 4001 ];  # Example AIS TCP port
  allowedUDPPorts = [ 10110 ];  # Common AIS UDP port
};
```

## File Locations

### Module Configuration
- **User/Group**: `ais` (dedicated system user)
- **Data Directory**: `/var/lib/aisdispatcher`
- **Web Interface**: Static files served from Nix store
- **Logs**: (none?) `/var/lib/aisdispatcher/logs/`
- **Configuration Files**:
  - Main config: Generated in Nix store (read-only, managed by NixOS options)
  - AIS settings: `/var/lib/aisdispatcher/aisdispatcher.json`
  - Runtime options: `/var/lib/aisdispatcher/aisdispatcher/aisdispatcher_rPiAIS001.opts`


## Service Management

The AIS Dispatcher runs as user systemd services under the `ais` user account:

```bash
# Status of the user session services
systemctl status user@$(id -u ais).service
systemctl stop user@$(id -u ais).service
systemctl start user@$(id -u ais).service
systemctl is-active user@$(id -u ais).service

# Check aiscontrol service status (main web interface)
sudo -u ais systemctl --user status aiscontrol

# Check dispatcher instance status
sudo -u ais systemctl --user status 'aisdispatcher@*'

# View logs
sudo -u ais journalctl --user -u aiscontrol -f
sudo -u ais journalctl --user -u 'aisdispatcher@*' -f

# Restart services
sudo -u ais systemctl --user restart aiscontrol
sudo -u ais systemctl --user restart 'aisdispatcher@*'

# Enable services (done automatically by NixOS module)
sudo -u ais systemctl --user enable aiscontrol
```

## Web Interface

Once running, the web interface is available at:
- HTTP: `http://localhost:8080` (redirects to HTTPS)
- HTTPS: `https://localhost:8043`

The interface allows you to:
- Configure AIS data sources (serial, TCP, UDP)
- Monitor received AIS messages
- Configure data forwarding destinations
- Manage system settings

## Notes

- The service runs as a dedicated `ais` user for security
- Configuration files are editable through the web interface
- The service automatically creates necessary directories and permissions
- Serial device access requires membership in appropriate groups (handled automatically)

## Architecture Support

The AIS Dispatcher upstream package provides binaries for multiple ARM architectures. The NixOS package maps these to NixOS system types as follows:

| Upstream Binary | NixOS System Type | Notes |
|-----------------|-------------------|-------|
| `x86_64` | `x86_64-linux` | Intel/AMD 64-bit |
| `armv8_a72` | `aarch64-linux` | ARM 64-bit (Cortex-A72) |
| `arm1176` | `armv7l-linux`, `armv6l-linux` | ARM 32-bit (ARM1176 is ARMv6) |
| `a7` | *unmapped* | Cortex-A7 (could map to `armv7l-linux`) |
| `a53` | *unmapped* | Cortex-A53 (could map to `aarch64-linux`) |

The package automatically selects the appropriate binary based on the target system architecture. Additional ARM variants use the most compatible available binary.