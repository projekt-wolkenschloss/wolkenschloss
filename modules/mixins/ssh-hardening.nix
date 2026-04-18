{
  config,
  lib,
  pkgs,
  ...
}:

let
  moduleConfig = config.wolkenschloss.modules.mixins.sshHardening;
in
{
  options.wolkenschloss.modules.mixins.sshHardening = {
    enable = lib.mkEnableOption "Enables SSH hardening mixin";

    sshPort = lib.mkOption {
      type = lib.types.ints.between 1024 65535;
      default = 45000;
      description = "The port on which the SSH server should listen.";
    };
  };

  config = lib.mkIf moduleConfig.enable {
    services.openssh = {
      enable = true;
      ports = [ moduleConfig.sshPort ];
      openFirewall = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        PermitEmptyPasswords = "no";
        X11Forwarding = false;
        MaxAuthTries = 3;
        # Disconnect clients that don't respond to keepalive messages after 10 mins (300s * 2)
        ClientAliveInterval = 300;
        ClientAliveCountMax = 2;
      };
    };

    environment.systemPackages = with pkgs; [
      endlessh-go
    ];

    # https://github.com/shizunge/endlessh-go
    services.endlessh-go = {
      enable = true;
      port = 22;
      openFirewall = true;
      extraOptions = [
        "-prometheus_clean_unseen_seconds 86400" # Clean unseen IPs after 24h
        # "-geoip_supplier ip-api"
      ];
      prometheus = {
        enable = true;
        port = 45001;
      };
    };
  };
}
