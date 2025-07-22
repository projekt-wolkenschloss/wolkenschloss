{ disko, ... }:
let
  bootDeviceId = "/dev/disk/by-id/scsi-0QEMU_QUEMU_HARDDISK_drive-scsi0";
in
{
  disko.devices = {
    disk = {
      bootDisk = {
        type = "disk";
        device = "${bootDeviceId}";
        content = {
          type = "gpt";
          partitions = {
            # Smaller EFI System Partition for space constraints
            esp = {
              label = "ESP";
              priority = 2;
              type = "EF00";
              size = "512M";
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

            # Smaller boot pool
            bpool = {
              size = "2G";
              content = {
                type = "zfs";
                pool = "bpool";
              };
            };

            # Root ZFS pool - rest of the disk
            rpool = {
              size = "-1M";
              content = {
                type = "zfs";
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

    zpool = {
      # Boot pool
      bpool = {
        type = "zpool";
        options = {
          ashift = 12;
          autotrim = "on";
          compatibility = "grub2";
        };
        rootFsOptions = {
          compression = "lz4";
          atime = "off";
          xattr = "sa";
          acltype = "posixacl";
          normalization = "formD";
          dnodesize = "auto";
          mountpoint = "none";
          canmount = "off";
          devices = "off";
          "com.sun:auto-snapshot" = "false";
        };
        mountpoint = "/boot";
        datasets = {
          nixos = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          "nixos/boot" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/boot";
          };
        };
      };

      # Root pool
      rpool = {
        type = "zpool";
        options = {
          ashift = 12;
          autotrim = "on";
        };
        rootFsOptions = {
          compression = "lz4";
          atime = "off";
          xattr = "sa";
          acltype = "posixacl";
          normalization = "formD";
          dnodesize = "auto";
          mountpoint = "none";
          canmount = "off";
          devices = "off";
          "com.sun:auto-snapshot" = "false";
        };
        mountpoint = "/";
        datasets = {
          nixos = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          "nixos/root" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/";
            postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^rpool/nixos/root@empty$' || zfs snapshot rpool/nixos/root@empty";
          };
          "nixos/var" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          "nixos/var/log" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/var/log";
          };
          "nixos/var/lib" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/var/lib";
          };
          "nixos/config" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/etc/nixos";
          };
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
          # No Docker volume for small disk to save space
          # Users can create it manually if needed
        };
      };
    };
  };
}
