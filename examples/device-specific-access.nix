# Example: Limiting AIS Dispatcher to a specific USB device
#
# This configuration restricts the ais user to access only a specific 
# AIS receiver device instead of all serial devices via dialout group.

{ config, ... }:

{
  services.aisdispatcher = {
    enable = true;
    port = 8080;
    websocketPort = 8081;
    interface = "0.0.0.0";
    openFirewall = true;
    
    # Remove broad serial access - we'll use device-specific permissions instead
    serialGroups = [ ];
  };

  # Create a dedicated group for the specific AIS device
  users.groups.ais-device = {};

  # Add the ais user to the device-specific group
  users.users.ais.extraGroups = [ "ais-device" ];

  # Create udev rules for your specific AIS receiver device
  services.udev.extraRules = ''
    # Example 1: FTDI-based AIS receiver (common for many devices)
    # Replace with your actual vendor/product IDs from lsusb
    SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", GROUP="ais-device", MODE="0660", TAG+="systemd"
    
    # Example 2: Match by device serial number (more specific)
    # SUBSYSTEM=="tty", ATTRS{serial}=="ABC123XYZ", GROUP="ais-device", MODE="0660", TAG+="systemd"
    
    # Example 3: Match by USB port location (physical port-specific)
    # SUBSYSTEM=="tty", KERNELS=="1-1.4:1.0", GROUP="ais-device", MODE="0660", TAG+="systemd"
    
    # Example 4: Prolific-based USB-to-serial adapter
    # SUBSYSTEM=="tty", ATTRS{idVendor}=="067b", ATTRS{idProduct}=="2303", GROUP="ais-device", MODE="0660", TAG+="systemd"
  '';

  # Optional: Ensure udev rules are reloaded
  system.activationScripts.reload-udev = ''
    ${config.systemd.package}/bin/udevadm control --reload-rules
    ${config.systemd.package}/bin/udevadm trigger --subsystem-match=tty
  '';
}