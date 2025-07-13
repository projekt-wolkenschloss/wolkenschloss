{ disko, ... }:
[
  disko.nixosModules.disko
  {
    disko.devices = {
      disk = {
        sdcard = {
          type = "disk";
          device = "/dev/mmcblk0";
          content = {
            type = "gpt";
            partitions = {

              firmware = {
                label = "FIRMWARE";
                priority = 1;
                type = "0700";
                attributes = [
                  0 # Required partition
                ];
                size = "1G";
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
              esp = {
                label = "ESP";
                priority = 2;
                type = "EF00"; # EFI System Partition (ESP)
                attributes = [
                  2 # Legacy BIOS Bootable, for U-Boot to find extlinux config
                ];
                size = "1G";
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

              "nixos/root" = {
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

            postCreateHook =
              let
                poolName = "rpool";
              in
              "zfs list -t snapshot -H -o name | grep -E '^${poolName}@blank$' || zfs snapshot ${poolName}@blank";
          };
        };
    };
  }
]
