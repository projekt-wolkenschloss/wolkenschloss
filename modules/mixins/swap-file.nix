{
  config,
  lib,
  ...
}:

{
  options.wolkenschloss.modules.mixins.swapFile = {
    enable = lib.mkEnableOption "Enable swap file with ZSwap for efficient swap management.";

    swapFileSize = lib.mkOption {
      type = lib.types.int;
      default = 32 * 1024;
      description = "Size of the swap file in MB.";
    };

    swapLocationStorageType = lib.mkOption {
      type = lib.types.enum [
        "ssd"
        "other"
      ];
      default = "ssd";
      description = "Type of storage where the swap file is located.";
    };
  };

  config =
    let
      moduleConfig = config.wolkenschloss.modules.mixins.swapFile;
    in
    lib.mkIf moduleConfig.enable {

      warnings =
        if (builtins.length config.swapDevices > 1) then
          [
            "There are other swap devices configured as well. Please make sure that they don't conflict: ${toString config.swapDevices}"
          ]
        else
          [ ];

      boot.kernelParams = [
        # ZSwap settings. See also https://wiki.archlinux.org/title/Zswap and https://wiki.nixos.org/wiki/Swap
        # enables zswap
        "zswap.enabled=1"
        # compression algorithm
        "zswap.compressor=zstd"
        # maximum percentage of RAM that zswap is allowed to use
        "zswap.max_pool_percent=10"
        # whether to shrink the pool proactively on high memory pressure
        "zswap.shrinker_enabled=1"
      ];

      swapDevices = [
        {
          device = "/var/lib/swapfile";
          size = moduleConfig.swapFileSize;
          # TRIM (discard) can help avoid unnecessary copy actions on SSDs, reducing wear and potentially helping increase performance.
          options = if (moduleConfig.swapLocationStorageType == "ssd") then [ "discard" ] else [ "defaults" ];
          randomEncryption = {
            enable = true;
            allowDiscards = if (moduleConfig.swapLocationStorageType == "ssd") then true else false;
          };
        }
      ];
    };
}
