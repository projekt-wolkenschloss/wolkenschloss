# NixOS configuration for small disk testing scenario with static IP
{ disko, ... }:
[
  {
    # Source: nixos options
    system.stateVersion = "25.05";

    # Source: nixos options
    hardware = {
      enableRedistributableFirmware = true;
    };

    # Source: nixos options
    boot = {
      supportedFilesystems = [ "zfs" ];
      kernelParams = [
        "zfs_force=1"
      ];
    };

    # Source: nixos options
    networking = {
      hostName = "nixos-testing-small";
      useDHCP = false; # Disable DHCP for static IP
      # Required by zfs
      hostId = "4a967f47";

      # Configure static IP
      interfaces = {
        eth0 = {
          useDHCP = false;
          ipv4.addresses = [
            {
              address = "192.168.1.100";
              prefixLength = 24;
            }
          ];
          ipv6.addresses = [ ];
        };
      };

      # Set default gateway
      defaultGateway = "192.168.1.1";
      nameservers = [
        "8.8.8.8"
        "8.8.4.4"
      ];
    };

    # Source: nixos options
    virtualisation.docker.storageDriver = "overlay2";

    # Source: nixos options
    services.openssh = {
      enable = true;
      openFirewall = true;
    };
  }

  disko.nixosModules.disko
  ./small-disk-disko.nix

  # Enable ZFS support and configure it
  {
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
