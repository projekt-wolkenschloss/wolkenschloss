{
  config,
  lib,
  ...
}:

let
  moduleConfig = config.wolkenschloss.modules.mixins.disableSleepAndHibernation;
in
{
  options.wolkenschloss.modules.mixins.disableSleepAndHibernation = {
    enable = lib.mkEnableOption "Disable any sleep or hibernation";
  };

  config = lib.mkIf moduleConfig.enable {
    services.logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
      IdleAction = "ignore";
      IdleActionSec = "infinity";
    };
    systemd.targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
  };
}
