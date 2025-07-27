{
  config,
  pkgs,
  installerName,
  ...
}:

{
  # ISO configuration
  isoImage = {
    isoName = "${installerName}-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.iso";
    volumeID = "WOLKENSCHLOSS";
    makeEfiBootable = true;
    makeUsbBootable = true;
  };

  # Basic system configuration
  system.stateVersion = "25.05";

  nixpkgs.config.allowUnfree = true;

  # Essential packages
  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    tmux
    vim
    wget
  ];

  # Network configuration
  networking = {
    usePredictableInterfaceNames = true;
    dhcpcd.enable = true;
    wireless.enable = false; # Disable if not needed
    useDHCP = false;
    interfaces = {
      # Auto-configure all interfaces with DHCP
    };
  };

  # Hardware support
  hardware.enableAllFirmware = true;

  users.motd = ''
    Welcome to Wolkenschloss Custom Installer!

    This system is ready for automated deployment.
  '';
}
