{ self, nixpkgs, disko, nixos-hardware, ... }:
[
  # Importing the nixos-hardware module for Raspberry Pi 3B
  nixos-hardware.nixosModules.raspberry-pi-3
  # Importing the Raspberry Pi 3B specific configuration
  ../devices/raspi-3B.nix
  {
    system.stateVersion = "25.05";
    networking.hostName = "sturmfeste";

    # Explicitly setting nix path for nixos-anywhere deployment
    # See https://github.com/nix-community/nixos-anywhere/blob/main/docs/howtos/nix-path.md
    nix.nixPath = [ "nixpkgs=${nixpkgs}" ];
    environment.systemPackages = with pkgs; [
      nano
    ];

    services.openssh = {
      enable = true;
      openFirewall = true;
    };
  }

  ./partitioning-disko.nix

  # Enable ZFS support and configure it
  {
    boot.supportedFilesystems = [ "zfs" ];
    services.zfs = {
      # Enables ZFS trimming, informing the storage devices about unused blocks that can be reclaimed
      trim.enable = true;
      trim.interval = "weekly";
      # Enables automatic scrubbing of ZFS pools.
      # Read more here: https://blogs.oracle.com/oracle-systems/post/disk-scrub-why-and-when
      autoScrub.enable = true;
      autoScrub.interval = "monthly";
    };
  }
]
