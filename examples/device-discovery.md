# Device Discovery for AIS Receivers

This guide helps you identify and configure access to specific AIS receiver device(s), allowing you to limit permissions instead of using the broad `dialout` group.

## Finding Your AIS Receiver Device

Will need the `usbutils` package for `lsusb` or `cyme`. The `usbutils` package is more common. The `cyme` package provides better formatting.

### 1. List USB Devices

#### Using lsusb (traditional, widely available)
```bash
# Show all USB devices with vendor/product IDs
lsusb

# Filter for common USB-to-serial chip manufacturers
lsusb | grep -E "(FTDI|Prolific|Silicon Labs|CH340)"
```

Example output:
```
Bus 001 Device 003: ID 0403:6001 Future Technology Devices International, Ltd FT232 USB-Serial (UART) IC
```

#### Using cyme (modern alternative with better formatting)
```bash
# Install cyme if desired (optional)
nix-shell -p cyme

# Show USB devices in a tree format with colors
cyme --tree --verbose

```

### 2. Find the Corresponding TTY Device

```bash
# Check recent kernel messages for new devices
dmesg | grep -E "(tty|USB)" | tail -20

# List available serial by-id devices:
ls -la /dev/serial/by-id/ | awk '/^[^td.]/ {print $9 " -> " $11}' | sed 's|../../||g'

# Find which device corresponds to your USB device
for device in /dev/ttyUSB* /dev/ttyACM*; do
  [ -e "$device" ] && echo "=== $device ===" && udevadm info -q property -n "$device" | grep -E "(ID_VENDOR|ID_MODEL|ID_SERIAL)"
done
```

### 3. Get Detailed Device Information

```bash
# Get comprehensive device info (replace /dev/ttyUSB0 with your device)
udevadm info -q property -n /dev/ttyACM1
udevadm info -a -n /dev/ttyUSB0

# Extract key identifiers
udevadm info -q property -n /dev/ttyUSB0 | grep -E "(ID_VENDOR_ID|ID_MODEL_ID|ID_SERIAL_SHORT)"
```

## Common AIS Receiver Device IDs

| Manufacturer | Vendor ID | Product ID | Notes |
|--------------|-----------|------------|-------|
| FTDI | 0403 | 6001 | FT232 (very common) |
| FTDI | 0403 | 6015 | FT231X |
| Prolific | 067b | 2303 | PL2303 |
| Silicon Labs | 10c4 | ea60 | CP2102/CP2109 |
| WCH | 1a86 | 7523 | CH340 |

## Creating Device-Specific Udev Rules

### By Vendor/Product ID (Recommended)
```bash
# Match any device with specific vendor/product ID
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", GROUP="ais-device", MODE="0660"
```

### By Serial Number (Most Specific)
```bash
# First find the serial number
udevadm info -q property -n /dev/ttyUSB0 | grep ID_SERIAL_SHORT

# Create rule matching that specific device
SUBSYSTEM=="tty", ATTRS{serial}=="ABC123XYZ", GROUP="ais-device", MODE="0660"
```

### By USB Port Location (Physical Port)
```bash
# Find the USB path
udevadm info -q property -n /dev/ttyUSB0 | grep DEVPATH

# Match device connected to specific USB port
SUBSYSTEM=="tty", KERNELS=="1-1.4:1.0", GROUP="ais-device", MODE="0660"
```

## Testing Your Configuration

### 1. Apply the Configuration
```bash
# Rebuild NixOS configuration
sudo nixos-rebuild switch

# Manually reload udev rules (if needed)
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=tty
```

### 2. Verify Permissions
```bash
# Check device permissions
ls -la /dev/ttyUSB0  # Should show ais-device group

# Verify the ais user can access the device
sudo -u ais cat < /dev/ttyUSB0  # Should not get permission denied

# Check group membership
groups ais  # Should include ais-device group
```

### 3. Test Device Communication
```bash
# Basic serial communication test (Ctrl+C to exit)
sudo -u ais screen /dev/ttyUSB0 38400

# Or using minicom
sudo -u ais minicom -D /dev/ttyUSB0 -b 38400
```

## Troubleshooting

### Device Not Found
- Ensure the device is properly connected
- Check `dmesg` for USB connection messages
- Verify the device appears in `lsusb`

### Permission Denied
- Confirm udev rules are loaded: `sudo udevadm control --reload-rules`
- Check the device group: `ls -la /dev/ttyUSB0`
- Verify user group membership: `groups ais`

### Multiple Devices
If you have multiple similar devices, use serial number matching to target the specific AIS receiver:

```bash
# List all devices with their serial numbers
for dev in /dev/ttyUSB*; do
  [ -e "$dev" ] && echo "$dev: $(udevadm info -q property -n "$dev" | grep ID_SERIAL_SHORT | cut -d= -f2)"
done
```

## Security Benefits

Using device-specific permissions instead of `dialout`:
- **Principle of least privilege**: Access only to required devices
- **Prevents accidental interference**: Can't affect other serial devices
- **Better audit trail**: Clear which device the service can access
- **Reduced attack surface**: Limited exposure if service is compromised