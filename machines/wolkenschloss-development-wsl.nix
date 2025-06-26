{
  self,
  nixos-wsl,
  home-manager,
  ...
}:
[
  nixos-wsl.nixosModules.default

  # Basic system configuration
  {
    system.stateVersion = "24.11";
    networking.hostName = "wolkenschloss-development-wsl";
    wsl.enable = true;
    wsl.defaultUser = "nixos";
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
  }

  home-manager.nixosModules.home-manager
  {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
  }

  ../users/wolke.nix
]
