# Disko config for a single storage device with ZFS root and boot pools.
{ disko, bootDeviceId, ... }:

{
  disko.devices = {
    disk = {
      bootDisk = {
        type = "disk";
        device = "${bootDeviceId}";
        content = {
          type = "gpt";
          partitions = {
            # EFI System Partition (ESP)
            esp = {
              label = "ESP";
              priority = 2;
              type = "EF00";
              size = "1G";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot/efis/${bootDeviceId}-part2";
                mountOptions = [
                  "noatime"
                  "noauto"
                  "x-systemd.automount"
                  "x-systemd.idle-timeout=1min"
                  "umask=0077"
                ];
              };
            };

            # Boot ZFS pool
            bpool = {
              size = "4G";
              content = {
                type = "zfs";
                # Name of the ZFS pool
                pool = "bpool";
              };
            };

            # Root ZFS pool
            rpool = {
              size = "-1M";
              content = {
                type = "zfs";
                # Name of the ZFS pool
                pool = "rpool";
              };
            };

            # BIOS boot partition
            bios = {
              size = "100%";
              type = "EF02";
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
          ashift = 12;
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
          camount = "off";
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
        # Boot pool
        bpool = {
          type = "zpool";
          options = commonPoolOptions // {
            # Enables grub2 support for ZFS
            compatibility = "grub2";
          };
          rootFsOptions = commonRootFsOptions;
          mountpoint = "/boot";
          datasets = {
            nixos = {
              type = "zfs_fs";
              options.mountpoint = "none";
            };

            "nixos/boot" = {
              type = "zfs_fs";
              # Use traditional fstab
              options.mountpoint = "legacy";
              mountpoint = "/boot";
            };
          };
        };

        # Root pool
        rpool = {
          type = "zpool";

          # General zfs pool properties
          options = commonPoolOptions;

          # zfs properties for the top level dataset
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
              postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^rpool/nixos/root@empty$' || zfs snapshot rpool/nixos/root@empty";
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

            "nixos/var/lib" = {
              type = "zfs_fs";
              # Use traditional fstab
              options.mountpoint = "legacy";
              mountpoint = "/var/lib";
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

            home = {
              type = "zfs_fs";
              options.mountpoint = "legacy";
              mountpoint = "/home";
            };

            # Container storage
            docker = {
              # Block device for ext4 fs
              type = "zfs_volume";
              size = "50G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/var/lib/containers";
              };
            };
          };
        };
      };
  };
}
