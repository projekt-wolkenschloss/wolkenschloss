# Disko config for a single storage device with ZFS root pool.
{
  disko,
  lib,
  disks ? [ "/dev/sda" ],
  rootZfsDatasetSnapshot ? "rpool/nixos/root@empty",
  ...
}:

{
  disko = {
    # extraRootModules = [ "zfs" ];
    devices = {
      disk = {
        bootDisk = {
          type = "disk";
          device = builtins.elemAt disks 0;
          content = {
            type = "gpt";
            partitions = {
              # EFI System Partition (ESP)
              esp = {
                label = "ESP";
                # sgdisk-specific short code
                type = "EF00";
                size = "1G";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [
                    "defaults"
                  ];
                };
              };
              
              # TODO move efi and bios parts to separate files and include based on arg
              # BIOS Boot Partition
              bios = {
                type = "EF02";  # BIOS boot partition type
                size = "1M";
                priority = 1;   # Make it first partition
                attributes = [ 0 ];
              };

              # Root ZFS pool
              rpool = {
                size = "100%";
                content = {
                  type = "zfs";
                  # Name of the ZFS pool
                  pool = "rpool";
                };
              };
            };
          };
        };
      };

      # Configures the ZFS pool
      zpool =
        let
          # General zfs pool properties
          commonPoolOptions = {
            ashift = "12";
            autotrim = "on";
          };

          # zfs properties for the top level dataset
          # For reference and background: https://jrs-s.net/2018/08/17/zfs-tuning-cheat-sheet/
          commonRootFsOptions = {
            compression = "lz4";
            atime = "off";
            xattr = "sa";
            acltype = "posixacl";
            # https://rubenerd.com/forgetting-to-set-utf-normalisation-on-a-zfs-pool/
            normalization = "formD";
            dnodesize = "auto";
            mountpoint = "none";
            # disables the use of device files (such as block devices or character devices) within the dataset.
            # This means that files like /dev/sda cannot be created or used inside that ZFS dataset.
            # It's a security feature to prevent users or processes from creating device nodes, which could potentially
            # be used to gain unauthorized access to system resources.
            devices = "off";
            # Disables auto snapshots feature of ZFS on the root dataset
            "com.sun:auto-snapshot" = "false";
          };
        in
        {
          # Root pool
          rpool = {
            type = "zpool";
            options = commonPoolOptions;
            rootFsOptions = commonRootFsOptions;
            mountpoint = "/";

            datasets = {
              # Parent dataset that will not be mounted
              nixos = {
                type = "zfs_fs";
                options.mountpoint = "none";
              };

              "nixos/root" = {
                type = "zfs_fs";
                # Use traditional fstab
                options.mountpoint = "legacy";
                mountpoint = "/";
                postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^${rootZfsDatasetSnapshot}$' || zfs snapshot ${rootZfsDatasetSnapshot}";
              };

              # Default NixOS configuration files
              "nixos/config" = {
                type = "zfs_fs";
                # Use traditional fstab
                options.mountpoint = "legacy";
                mountpoint = "/etc/nixos";
              };

              # Nix package store (e.g. all installed packages)
              "nixos/nix" = {
                type = "zfs_fs";
                options.mountpoint = "legacy";
                mountpoint = "/nix";
              };

              "nixos/home" = {
                type = "zfs_fs";
                options.mountpoint = "legacy";
                mountpoint = "/home";
              };

              "nixos/var" = {
                type = "zfs_fs";
                options.mountpoint = "none";
              };

              # Application and system logs
              "nixos/var/log" = {
                type = "zfs_fs";
                # Use traditional fstab
                options.mountpoint = "legacy";
                mountpoint = "/var/log";
              };
            };
          };
        };

    };
  };

  fileSystems = {
    "/" = lib.mkForce {
      device = "rpool/nixos/root";
      fsType = "zfs";
    };

    "./nix" = {
      device = "rpool/nixos/nix";
      fsType = "zfs";
      neededForBoot = true;
    };

    "/etc/nixos" = {
      device = "rpool/nixos/config";
      fsType = "zfs";
      neededForBoot = true;
    };

    "nixos/home" = {
      device = "rpool/nixos/home";
      fsType = "zfs";
      neededForBoot = true;
    };

    "nixos/var/log" = {
      device = "rpool/nixos/var/log";
      fsType = "zfs";
      neededForBoot = true;
    };
  };
}
