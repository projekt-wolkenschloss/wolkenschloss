# Configures nix settings used system-wide.
{
  config,
  lib,
  ...
}:

let
  cfg = config.wolkenschloss.modules.mixins.nix;
in
{
  options.wolkenschloss.modules.mixins.nix = {
    enable = lib.mkEnableOption "Nix settings and optimisations";

    trusted-users = lib.mkOption {
      description = "List of trusted users for the nix daemon. See also https://github.com/NixOS/nixpkgs/blob/nixos-25.05/nixos/modules/config/nix.nix";
      type = lib.types.listOf lib.types.str;

      # allows nix-copy to the live system
      default = [
        "root"
        "@wheel"
      ];
    };

    download-buffer-size = lib.mkOption {
      description = "Size of the download buffer for nix binary caches in bytes. Deprecated in favor of downloadBufferSizeMb";
      type = lib.types.ints.unsigned;
      default = 524288000; # 500MB
    };

    downloadBufferSizeMb = lib.mkOption {
      description = "Size of the download buffer for nix binary caches in megabytes. See also https://github.com/NixOS/nix/issues/11728";
      type = lib.types.nullOr lib.types.ints.unsigned;
      default = null;
      example = 500;
    };
  };

  config = lib.mkIf cfg.enable {
    nix =
      let
        bufferSize =
          if cfg.downloadBufferSizeMb != null then
            cfg.downloadBufferSizeMb * 1024 * 1024
          else
            cfg.download-buffer-size;
      in
      {
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          trusted-users = cfg.trusted-users;
          # Enables to download more from the binary caches?
          download-buffer-size = bufferSize;
        };
        # Turn on periodic optimisation of the nix store. De-duplicates store paths using hard links except in containers where the store is host-managed.
        optimise.automatic = lib.mkDefault (!config.boot.isContainer);

        gc = lib.mkDefault {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 30d";
        };

      };

    # Make builds to be more likely killed than important services.
    # 100 is the default for user slices and 500 is systemd-coredumpd@
    # We rather want a build to be killed than our precious user sessions as builds can be easily restarted.
    systemd.services.nix-daemon.serviceConfig.OOMScoreAdjust = lib.mkDefault 250;
  };
}
