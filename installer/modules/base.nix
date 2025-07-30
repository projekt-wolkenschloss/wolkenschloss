{
  config,
  pkgs,
  installerName,
  hostName,
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
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  services.xserver.xkb.layout = "de"; # Set default keyboard layout
  console.keyMap = "de"; # Set console keyboard layout

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
    hostName = "${hostName}";
    usePredictableInterfaceNames = true;
    dhcpcd.enable = true;
    wireless.enable = false; # Disable if not needed
    useDHCP = true;
  };

  # Enables mDNS for local network service discovery
  services.avahi = {
    enable = true;
    nssmdns4 = true; # Enable resolution of .local domains
    openFirewall = true; # Allow mDNS traffic through the firewall
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  # Hardware support
  hardware.enableAllFirmware = true;

  users.motd = ''
    Welcome to Wolkenschloss Custom Installer!

    This system is ready for automated deployment.
  '';
}
