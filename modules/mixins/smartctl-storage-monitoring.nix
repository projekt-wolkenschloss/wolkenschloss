{
  config,
  lib,
  pkgs,
  ...
}:

let
  moduleConfig = config.wolkenschloss.modules.mixins.smartctlStorageMonitoring;
in
{
  options.wolkenschloss.modules.mixins.smartctlStorageMonitoring = {
    enable = lib.mkEnableOption "Enables and configures the smartmontools to monitor system storage devices.";
  };

  config = lib.mkIf moduleConfig.enable {

    environment.systemPackages = with pkgs; [
      smartmontools
    ];

    services.smartd = {
      enable = true;
      autodetect = true;
      # -a monitor all the things
      # -o automatic offline testing
      # -s schedule testing: Short test daily at 02:00, Long test weekly at 04:00 on Sundays
      defaults.autodetected = "-a -o on -s (S/../.././02|L/../../7/04)";
    };

    services.prometheus.exporters.smartctl = {
      enable = true;
      port = 9633;
      maxInterval = "60s";
      listenAddress = "127.0.0.1";
    };

    # Grant disk group access to NVMe controller character devices.
    # By default /dev/nvme* controllers are root:root 0600, which blocks
    # non-root smartctl access even with capabilities.
    services.udev.extraRules = ''
      KERNEL=="nvme[0-9]*", SUBSYSTEM=="nvme", GROUP="disk", MODE="0660"
    '';

    # Extend cgroup device access for smartctl exporter.
    # Use block-nvme class to cover all NVMe namespaces (nvme0n1, nvme1n1, etc.).
    # char-nvme is already set by upstream but we ensure it's present.
    systemd.services."prometheus-smartctl-exporter".serviceConfig.DeviceAllow = lib.mkAfter [
      "block-nvme rw"
      "char-nvme rw"
    ];
  };
}
