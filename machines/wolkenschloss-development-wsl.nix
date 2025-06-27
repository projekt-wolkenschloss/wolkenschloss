{
  self,
  nixos-wsl,
  home-manager,
  ...
}:
[
  # Enables WSL support
  nixos-wsl.nixosModules.default

  # Basic system configuration
  {
    system.stateVersion = "24.11";
    networking.hostName = "wolkenschloss-development-wsl";
    wsl.enable = true;
    wsl.defaultUser = "wolke";
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    boot.loader.systemd-boot.configurationLimit = 10;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 1w";
    };
    time.timeZone = "Europe/Berlin";
  }

  # Activating home manager
  home-manager.nixosModules.home-manager
  {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
  }

  # Configures users
  ../users/wolke.nix
]
