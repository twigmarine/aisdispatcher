{
  description = "Example NixOS system with AIS Dispatcher";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    aisdispatcher.url = "github:twigmarine/aisdispatcher";
  };

  outputs = { self, nixpkgs, aisdispatcher }:
  {
    nixosConfigurations.example-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import the AIS Dispatcher module
        aisdispatcher.nixosModules.default
        
        # Your system configuration
        {
          # Basic system configuration
          system.stateVersion = "24.05";
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;
          
          # Network configuration
          networking.hostName = "ais-station";
          networking.networkmanager.enable = true;
          
          # Enable SSH for remote management
          services.openssh = {
            enable = true;
            settings.PermitRootLogin = "no";
          };
          
          # AIS Dispatcher configuration - Basic setup
          services.aisdispatcher = {
            enable = true;
            port = 8080;
            websocketPort = 8081;
            interface = "0.0.0.0";
            openFirewall = true;
            sessionTimeout = 1800; # 30 minutes
          };
          
          # Create a regular user
          users.users.admin = {
            isNormalUser = true;
            extraGroups = [ "wheel" "networkmanager" ];
          };
        }
      ];
    };

    # Alternative configuration with device-specific access
    nixosConfigurations.ais-station-secure = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        aisdispatcher.nixosModules.default
        {
          system.stateVersion = "24.05";
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;
          
          networking.hostName = "ais-station-secure";
          networking.networkmanager.enable = true;
          
          services.openssh = {
            enable = true;
            settings.PermitRootLogin = "no";
          };
          
          # AIS Dispatcher with device-specific access (secure)
          services.aisdispatcher = {
            enable = true;
            port = 8080;
            websocketPort = 8081;
            interface = "127.0.0.1"; # Only local access
            openFirewall = false;    # Manual firewall control
            serialGroups = [ ];      # No broad serial access
          };
          
          # Create device-specific group and udev rules
          users.groups.ais-device = {};
          users.users.ais.extraGroups = [ "ais-device" ];
          
          # Example udev rule for dAISy AIS Receiver
          services.udev.extraRules = ''
            # dAISy AIS Receiver (Adrian Studer)
            SUBSYSTEM=="tty", ATTRS{idVendor}=="16d0", ATTRS{idProduct}=="0b03", GROUP="ais-device", MODE="0660", TAG+="systemd"
          '';
          
          # Caddy reverse proxy for HTTPS access
          services.caddy = {
            enable = true;
            virtualHosts."ais.local" = {
              extraConfig = ''
                # Handle websocket connections
                handle /realtime* {
                  reverse_proxy 127.0.0.1:8081
                }
                
                # Serve static files directly
                handle /static/* {
                  root * ${aisdispatcher.packages.x86_64-linux.aisdispatcher}/share/aisdispatcher/htdocs
                  file_server
                }
                
                # Proxy API calls
                handle /api/* {
                  reverse_proxy 127.0.0.1:8080
                }
                
                # Default to static files
                handle {
                  root * ${aisdispatcher.packages.x86_64-linux.aisdispatcher}/share/aisdispatcher/htdocs
                  try_files {path} /index.html
                  file_server
                }
              '';
            };
          };
          
          # Open only HTTPS port
          networking.firewall.allowedTCPPorts = [ 80 443 ];
          
          users.users.admin = {
            isNormalUser = true;
            extraGroups = [ "wheel" "networkmanager" ];
          };
        }
      ];
    };
  };
}