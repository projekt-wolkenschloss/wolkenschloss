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

  disko.nixosModules.disko
  {
    disko.devices.disk = {
      sdcard = {
        type = "disk";
        device = "/dev/mmcblk0";
        content = {
          type = "gpt";
          partitions = {

            FIRMWARE = {
              label = "FIRMWARE";
              priority = 1;
              type = "0700";
              attributes = [
                0 # Required partition
              ];
              size = "1024M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot/firmware";
                mountOptions = [
                  "noatime"
                  "noauto"
                  "x-systemd.automount"
                  "x-systemd.idle-timeout=1min"
                ];
              };
            };

            # EFI System Partition (ESP)
            ESP = {
              label = "ESP";
              priority = 2;
              type = "EF00";  # EFI System Partition (ESP)
              attributes = [
                2 # Legacy BIOS Bootable, for U-Boot to find extlinux config
              ];
              size = "1024M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "noatime"
                  "noauto"
                  "x-systemd.automount"
                  "x-systemd.idle-timeout=1min"
                  "umask=0077"
                ];
              };
            };

            # Configures ZFS pool
            zpool = {
              # Root Pool
              rpool = {
                type = "zpool";
                # zpool properties
                options = {
                  ashift = 12;
                  autotrim = "on";
                };

                # zfs properties
                # For reference and background: https://jrs-s.net/2018/08/17/zfs-tuning-cheat-sheet/
                rootFsOptions = {
                  compression = "lz4";
                  atime = "off";
                  xattr = "sa";
                  acltype = "posixacl";
                  # https://rubenerd.com/forgetting-to-set-utf-normalisation-on-a-zfs-pool/
                  normalization = "formD";
                  dnodesize = "auto";
                  mountpoint = "none";
                  camount = "off";
                };


                postCreateHook = let
                  poolName = "rpool";
                in "zfs list -t snapshot -H -o name | grep -E '^${poolName}@blank$' || zfs snapshot ${poolName}@blank";
              };
            };
          };
        };
      };
    };
  }
]
