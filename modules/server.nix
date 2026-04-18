{
  config,
  lib,
  pkgs,
  ...
}:

let
  moduleConfig = config.wolkenschloss.modules.server;
in
{

  imports = [
    ./mixins
  ];

  options.wolkenschloss.modules.server = {
    enable = lib.mkEnableOption "Enables the server role";

    adminPublicKey = lib.mkOption {
      type = lib.types.str;
      description = "The public SSH key of the administrator user.";
      example = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICV...";
    };
  };

  config = lib.mkIf moduleConfig.enable {

    # Better D-Bus implementation for better performance and reliability
    services.dbus.implementation = "broker";
    # User management improvements
    services.userborn.enable = true;
    # User accounts are immutable
    users.mutableUsers = false;

    console.keyMap = lib.mkDefault "de";
    time.timeZone = lib.mkDefault "Europe/Berlin";

    # Do not take down the network for too long when upgrading,
    # This also prevents failures of services that are restarted instead of stopped.
    # It will use `systemctl restart` rather than stopping it with `systemctl stop`
    # followed by a delayed `systemctl start`.
    systemd.services = {
      systemd-networkd.stopIfChanged = false;
      # Services that are only restarted might be not able to resolve when resolved is stopped before
      systemd-resolved.stopIfChanged = false;
    };

    # Don't install the /lib/ld-linux.so.2 stub. This saves one instance of nixpkgs.
    environment.ldso32 = null;

    # Ensure a clean & sparkling /tmp on fresh boots.
    boot.tmp.cleanOnBoot = lib.mkDefault true;

    # Use recommended bootloader for NixOS
    boot.loader.systemd-boot.enable = lib.mkDefault (pkgs.stdenv.isx86_64 || pkgs.stdenv.isx86_32);

    # Allow PMTU / DHCP
    networking.firewall.allowPing = true;

    # Allow remote access
    services.openssh.enable = true;

    # Allow firmware with license that allows redistribution. Required to for example microcode updates on Intel CPUs.
    hardware.enableRedistributableFirmware = true;

    # Allow unfree packages
    nixpkgs.config.allowUnfree = true;

    # In case of a laptop, stop it from going to sleep on lid close.
    wolkenschloss.modules.mixins.disableSleepAndHibernation.enable = lib.mkDefault true;

    wolkenschloss.modules.mixins.nixosAdminUser = {
      enable = true;
      user = {
        name = "nixos";
        sshPublicKey = moduleConfig.adminPublicKey;
      };
    };

    wolkenschloss.modules.mixins.sshHardening.enable = lib.mkDefault true;
    wolkenschloss.modules.mixins.nix.enable = lib.mkDefault true;
    wolkenschloss.modules.mixins.swapFile.enable = lib.mkDefault true;
    wolkenschloss.modules.mixins.cpuPerformanceScaling.enable = lib.mkDefault true;
    wolkenschloss.modules.mixins.sops.enable = lib.mkDefault true;
    wolkenschloss.modules.mixins.smartctlStorageMonitoring.enable = lib.mkDefault true;
    wolkenschloss.modules.mixins.grafanaAlloyAgent.enable = lib.mkDefault true;
  };
}
