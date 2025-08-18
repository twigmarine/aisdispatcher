# Example Client Flake

This directory contains an example flake showing how to use the AIS Dispatcher module in your NixOS system configuration.

## Quick Start

1. **Clone or copy this example:**
   ```bash
   cp -r examples/client-flake /path/to/your/nixos-config
   cd /path/to/your/nixos-config
   ```

2. **Build the system:**
   ```bash
   # Build the basic configuration
   nixos-rebuild build --flake .#example-host
   
   # Or build the secure configuration with Caddy
   nixos-rebuild build --flake .#ais-station-secure
   ```

3. **Deploy to your system:**
   ```bash
   sudo nixos-rebuild switch --flake .#example-host
   ```

## Configurations Included

### `example-host` - Basic Setup
- AIS Dispatcher with default settings
- Web interface on port 8080, WebSocket on 8081
- Open firewall for direct access
- Uses `dialout` group for serial device access

### `ais-station-secure` - Secure Setup
- Device-specific access (example for dAISy receiver)
- Caddy reverse proxy with HTTPS
- Local-only AIS Dispatcher binding
- Manual firewall control

## Customization

### Change the AIS Receiver Device
Edit the udev rule in the secure configuration:

```nix
services.udev.extraRules = ''
  # Replace with your device's vendor/product ID
  SUBSYSTEM=="tty", ATTRS{idVendor}=="XXXX", ATTRS{idProduct}=="YYYY", GROUP="ais-device", MODE="0660", TAG+="systemd"
'';
```

Find your device IDs using:
```bash
# List devices with vendor/product IDs
lsusb

# Or get stable by-id paths
ls -la /dev/serial/by-id/
```

### Adjust Network Settings
Modify the interface binding and ports:

```nix
services.aisdispatcher = {
  port = 8080;              # Web interface port
  websocketPort = 8081;     # WebSocket port  
  interface = "0.0.0.0";    # Bind to all interfaces
  openFirewall = true;      # Automatic firewall rules
};
```

### Add Additional Services
The flake structure makes it easy to add other services:

```nix
# Add monitoring
services.prometheus = {
  enable = true;
  exporters.node.enable = true;
};

# Add log management  
services.journald.extraConfig = ''
  MaxRetentionSec=30d
  MaxFileSec=1d
'';
```

## Deployment Options

### Local System
```bash
sudo nixos-rebuild switch --flake .#example-host
```

### Remote System
```bash
nixos-rebuild switch --flake .#example-host --target-host user@hostname
```

### Build Only (Testing)
```bash
nixos-rebuild build --flake .#example-host
```

## Troubleshooting

### Check AIS Dispatcher Status
```bash
# Basic service status
sudo -u ais systemctl --user status aiscontrol

# View logs
sudo -u ais journalctl --user -u aiscontrol -f
```

### Test Device Access
```bash
# Check device permissions
ls -la /dev/ttyACM* /dev/ttyUSB*

# Verify group membership
groups ais

# Test serial communication
sudo -u ais screen /dev/ttyACM0 38400
```

### Web Interface Access
- **Basic setup**: `http://hostname:8080`
- **Secure setup**: `https://ais.local` (add to /etc/hosts if needed)

## Integration with Existing Configs

To add AIS Dispatcher to an existing NixOS configuration:

1. **Add the input to your flake:**
   ```nix
   inputs.aisdispatcher.url = "github:twigmarine/aisdispatcher";
   ```

2. **Import the module:**
   ```nix
   modules = [
     aisdispatcher.nixosModules.default
     # ... your other modules
   ];
   ```

3. **Configure the service:**
   ```nix
   services.aisdispatcher.enable = true;
   # ... other options
   ```