{
  config,
  lib,
  ...
}:

let
  moduleConfig = config.wolkenschloss.modules.disko.simpleExt4;
in
{
  options.wolkenschloss.modules.disko.simpleExt4 = {

    enable = lib.mkEnableOption "Enables a simple ext4 root partition on an NVMe device using disko.";

    rootDevice = lib.mkOption {
      type = lib.types.str;
      description = "The block device to use for the root partition (e.g. /dev/nvme0n1).";
      example = "/dev/nvme0n1";
    };
  };

  config =
    let
      deviceName = lib.last (lib.splitString "/" moduleConfig.rootDevice);
    in
    lib.mkIf moduleConfig.enable {
      disko.devices = {
        disk.${deviceName} = {
          type = "disk";
          device = moduleConfig.rootDevice;
          content = {
            type = "gpt";
            partitions = {

              ESP = {
                type = "EF00"; # EFI System Partition (ESP)
                attributes = [
                  2 # Legacy BIOS Bootable
                ];
                size = "500M";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [
                    "umask=0077"
                  ];
                };
              };

              root = {
                size = "100%";
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };
              };
            };
          };
        };
      };
    };
}
