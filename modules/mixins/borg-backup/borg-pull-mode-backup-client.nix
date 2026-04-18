{
  config,
  lib,
  pkgs,
  ...
}:

let
  moduleConfig = config.wolkenschloss.modules.mixins.borgPullModeBackupClient;
in
{
  options.wolkenschloss.modules.mixins.borgPullModeBackupClient = {
    enable = lib.mkEnableOption "Borg pull mode backup client configuration";
  };

  config = lib.mkIf moduleConfig.enable {
    services.openssh = {
      enable = true;
      settings = {
        AllowStreamLocalForwarding = "yes";
        StreamLocalBindUnlink = "yes";
      };
    };

    environment.systemPackages = [
      pkgs.borgbackup
      pkgs.socat
    ];
  };
}
