{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.kokoro-fastapi;
in {
  options.services.kokoro-fastapi = {
    enable = mkEnableOption "Kokoro-FastAPI TTS service";

    port = mkOption {
      type = types.port;
      default = 8880;
      description = "Port on which Kokoro-FastAPI will listen";
    };

    useGpu = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to use GPU acceleration (requires NVIDIA GPU and docker with GPU support)";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/kokoro-fastapi";
      description = "Directory to store Kokoro-FastAPI data and repository";
    };

    user = mkOption {
      type = types.str;
      default = "kokoro-fastapi";
      description = "User to run the Kokoro-FastAPI service";
    };

    group = mkOption {
      type = types.str;
      default = "kokoro-fastapi";
      description = "Group to run the Kokoro-FastAPI service";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = {
        ONNX_NUM_THREADS = "8";
        ONNX_INTER_OP_THREADS = "4";
        ONNX_EXECUTION_MODE = "parallel";
        ONNX_OPTIMIZATION_LEVEL = "all";
        ONNX_MEMORY_PATTERN = "true";
        ONNX_ARENA_EXTEND_STRATEGY = "kNextPowerOfTwo";
      };
      description = "Environment variables to pass to the service";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the firewall for the Kokoro-FastAPI service";
    };
  };

  config = mkIf cfg.enable {
    # Create user and group for the service
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      extraGroups = [ "docker" ];
    };

    users.groups.${cfg.group} = {};

    # Enable Docker
    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;
    };

    # Create systemd service
    systemd.services.kokoro-fastapi = {
      description = "Kokoro-FastAPI TTS Service";
      after = [ "network.target" "docker.service" ];
      wants = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];

      environment = cfg.environment // {
        HOME = cfg.dataDir;
        DOCKER_BUILDKIT = "1";
      };

      serviceConfig = {
        Type = "exec";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        Restart = "always";
        RestartSec = "10";
        TimeoutStartSec = "300";
        TimeoutStopSec = "60";
        
        ExecStartPre = [
          # Ensure data directory exists and has correct permissions
          "${pkgs.coreutils}/bin/mkdir -p ${cfg.dataDir}"
          "${pkgs.coreutils}/bin/chown ${cfg.user}:${cfg.group} ${cfg.dataDir}"
          
          # Clone or update repository
          "${pkgs.bash}/bin/bash -c 'cd ${cfg.dataDir} && if [ ! -d Kokoro-FastAPI ]; then ${pkgs.git}/bin/git clone https://github.com/remsky/Kokoro-FastAPI.git; else cd Kokoro-FastAPI && ${pkgs.git}/bin/git fetch origin && ${pkgs.git}/bin/git reset --hard origin/master; fi'"
          
          # Ensure proper permissions
          "${pkgs.coreutils}/bin/chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}/Kokoro-FastAPI"
          
          # Stop any existing containers
          "${pkgs.bash}/bin/bash -c 'cd ${cfg.dataDir}/Kokoro-FastAPI/docker/${if cfg.useGpu then "gpu" else "cpu"} && ${pkgs.docker-compose}/bin/docker-compose down || true'"
        ];
        
        ExecStart = "${pkgs.bash}/bin/bash -c 'cd ${cfg.dataDir}/Kokoro-FastAPI/docker/${if cfg.useGpu then "gpu" else "cpu"} && PORT=${toString cfg.port} ${pkgs.docker-compose}/bin/docker-compose up --build'";
        
        ExecStop = "${pkgs.bash}/bin/bash -c 'cd ${cfg.dataDir}/Kokoro-FastAPI/docker/${if cfg.useGpu then "gpu" else "cpu"} && ${pkgs.docker-compose}/bin/docker-compose down'";
      };
    };

    # Configure firewall
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    # Ensure required packages are available in the system
    environment.systemPackages = with pkgs; [
      docker-compose
      git
    ];

    # Add some useful information to the system
    system.activationScripts.kokoro-fastapi-info = ''
      echo "Kokoro-FastAPI will be available at:"
      echo "  API: http://localhost:${toString cfg.port}"
      echo "  Docs: http://localhost:${toString cfg.port}/docs" 
      echo "  Web UI: http://localhost:${toString cfg.port}/web"
      echo ""
      echo "Service management:"
      echo "  Start: systemctl start kokoro-fastapi"
      echo "  Stop: systemctl stop kokoro-fastapi"
      echo "  Status: systemctl status kokoro-fastapi"
      echo "  Logs: journalctl -u kokoro-fastapi -f"
    '';
  };
}