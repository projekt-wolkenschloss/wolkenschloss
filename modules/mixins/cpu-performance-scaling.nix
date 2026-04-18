{
  config,
  lib,
  ...
}:

let
  moduleConfig = config.wolkenschloss.modules.mixins.cpuPerformanceScaling;
in

{
  options.wolkenschloss.modules.mixins.cpuPerformanceScaling = {
    enable = lib.mkEnableOption "Enable CPU frequency scaling for performance";
  };

  config = lib.mkIf moduleConfig.enable {
    services.auto-cpufreq = {
      enable = true;
      settings = {
        battery = {
          governor = "powersave";
          turbo = "never";
        };
        charger = {
          # see available governors: cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
          governor = "performance";
          # see available preferences: cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_available_preferences
          energy_performance_preference = "balance_performance";
          turbo = "auto";
        };
      };
    };
  };
}
