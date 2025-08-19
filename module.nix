{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.aisdispatcher;
  aisdispatcher = pkgs.callPackage ./package.nix { };
  
  # Generate aiscontrol.cfg file
  aiscontrolConfig = pkgs.writeText "aiscontrol.cfg" ''
    listen_host = ${cfg.interface}
    listen_port = ${toString cfg.port}
    
    ws_listen_host = ${cfg.websocketInterface}
    ws_listen_port = ${toString cfg.websocketPort}
    
    htdocs = ${aisdispatcher}/share/aisdispatcher/htdocs
    session_key = ${cfg.sessionKey}
    session_timeout = ${toString cfg.sessionTimeout}
    password_file = ${cfg.dataDir}/admin_password
    config_dir = ${cfg.dataDir}/aisdispatcher
    json_config = ${cfg.dataDir}/aisdispatcher.json
    networkctl = ${if cfg.enableNetworkctl then "true" else "false"}
  '';
in {
  meta = {
    maintainers = with lib.maintainers; [ ]; # Add your name here
    # description
    # homepage  
    # downloadPage
  };
  options.services.aisdispatcher = {
    enable = mkEnableOption "AIS Dispatcher service";

    user = mkOption {
      type = types.str;
      default = "ais";
      description = "User account under which AIS Dispatcher runs";
    };

    group = mkOption {
      type = types.str;
      default = "ais";
      description = "Group account under which AIS Dispatcher runs";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/aisdispatcher";
      description = "Directory where AIS Dispatcher stores its data";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port for the web interface";
    };

    websocketPort = mkOption {
      type = types.port;
      default = 8081;
      description = "Port for the websocket interface";
    };

    interface = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Interface to bind the web server to";
    };

    websocketInterface = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Interface to bind the websocket server to";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to open the firewall for the web interface and websocket ports.
        
        Note: If you configure AIS Dispatcher to use TCP/UDP server mode for 
        receiving AIS data (via the web UI), you'll need to manually open 
        those additional ports in your firewall configuration.
      '';
    };

    sessionTimeout = mkOption {
      type = types.int;
      default = 900;
      description = "Session timeout in seconds";
    };

    serialGroups = mkOption {
      type = types.listOf types.str;
      default = [ "dialout" ];
      description = "Additional groups for serial device access";
    };

    sessionKey = mkOption {
      type = types.str;
      default = "auto";
      description = "Session key for web interface authentication (use 'auto' for automatic generation)";
    };

    enableNetworkctl = mkOption {
      type = types.bool;
      default = true;
      description = "Enable networkctl integration";
    };

    # Read-only computed options for integration with other services
    package = mkOption {
      type = types.package;
      readOnly = true;
      description = "The AIS Dispatcher package being used";
    };

    htdocsPath = mkOption {
      type = types.path;
      readOnly = true;
      description = ''
        Path to the static web files (htdocs) in the Nix store.
        Useful for configuring web servers like Caddy to serve static files directly.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Set read-only computed options  
    services.aisdispatcher.package = mkDefault aisdispatcher;
    services.aisdispatcher.htdocsPath = mkDefault "${aisdispatcher}/share/aisdispatcher/htdocs";

    # Create user and group
    users.groups.${cfg.group} = {};
    
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      description = "AIS Dispatcher service user";
      home = cfg.dataDir;
      createHome = true;
      extraGroups = cfg.serialGroups ++ [ "systemd-journal" ];
      linger = true;
    };

    # Create data directory
    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0755 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.dataDir}/aisdispatcher' 0755 ${cfg.user} ${cfg.group} - -"
      "d '${cfg.dataDir}/logs' 0755 ${cfg.user} ${cfg.group} - -"
    ];

    # Copy default configuration files if they don't exist
    system.activationScripts.aisdispatcher-config = ''
      # Copy aisdispatcher directory if it doesn't exist
      if [ ! -d "${cfg.dataDir}/aisdispatcher" ]; then
        mkdir -p ${cfg.dataDir}/aisdispatcher
        cp -rp ${aisdispatcher}/share/aisdispatcher/etc/aisdispatcher/* ${cfg.dataDir}/aisdispatcher/ || true
      fi

      # Copy aisdispatcher.json if it doesn't exist
      if [ ! -f "${cfg.dataDir}/aisdispatcher.json" ]; then
        cp -p ${aisdispatcher}/share/aisdispatcher/etc/aisdispatcher.json ${cfg.dataDir}/aisdispatcher.json || true
      fi

      # Ensure directory has correct ownership and permissions
      chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}
      chmod 644 ${cfg.dataDir}/aisdispatcher.json
      chmod 640 ${cfg.dataDir}/aisdispatcher/aisdispatcher_rPiAIS001.opts
    '';

    # Create user-specific systemd configuration
    # I don't know how else to do it.
    system.activationScripts.aisdispatcher-user-services = ''
      # Create user systemd directory
      mkdir -p ${cfg.dataDir}/.config/systemd/user
      
      # Create aisdispatcher@ template service
      cat > ${cfg.dataDir}/.config/systemd/user/aisdispatcher@.service << 'EOF'
[Unit]
Description=AIS Dispatcher %I
After=network.target
ConditionFileNotEmpty=${cfg.dataDir}/aisdispatcher/aisdispatcher_%i.opts

[Service]
WorkingDirectory=${cfg.dataDir}
EnvironmentFile=${cfg.dataDir}/aisdispatcher/aisdispatcher_%i.opts
ExecStart=${aisdispatcher}/bin/aisdispatcher -s %i
Restart=always
ExecReload=/bin/kill -HUP $MAINPID
Environment=HOME=${cfg.dataDir}

[Install]
WantedBy=basic.target
EOF

      # Create aiscontrol service
      cat > ${cfg.dataDir}/.config/systemd/user/aiscontrol.service << 'EOF'
[Unit]
Description=AIS Control Service
After=network.target

[Service]
WorkingDirectory=${cfg.dataDir}
ExecStart=${aisdispatcher}/bin/aiscontrol --config ${aiscontrolConfig}
Restart=always
Environment=HOME=${cfg.dataDir}

[Install]
WantedBy=basic.target
EOF

      # Set ownership
      chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}/.config
      
      # Enable and start user services
      #sudo -u ${cfg.user} XDG_RUNTIME_DIR=/run/user/$(id -u ${cfg.user}) systemctl --user daemon-reload
      #sudo -u ${cfg.user} XDG_RUNTIME_DIR=/run/user/$(id -u ${cfg.user}) systemctl --user enable aiscontrol || true
    '';

    # Firewall
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port cfg.websocketPort ];
    };

    # Add package to system packages
    environment.systemPackages = [ aisdispatcher ];
  };
}