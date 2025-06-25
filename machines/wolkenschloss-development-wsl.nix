{ self, nixos-wsl, ... }:
[
  nixos-wsl.nixosModules.default

  # Basic system configuration
  {
    system.stateVersion = "24.11";
    networking.hostName = "wolkenschloss-development-wsl";
    wsl.enable = true;
    wsl.defaultUser = "nixos";
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    boot.loader.systemd-boot.configurationLimit = 10;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 1w";
    };
  }

  # TODO add users
  # TODO add home manager

]
