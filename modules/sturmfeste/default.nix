{
  inputs,
  lib,
  config,
  ...
}:

let
  moduleCfg = config.pwks.sturmfeste;
in
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.sops-nix.nixosModules.sops
    ../disko
    ../server.nix
  ];

  options.pwks.sturmfeste = {
    enable = lib.mkEnableOption "Enables the Sturmfeste role";

    adminPublicKey = lib.mkOption {
      type = lib.types.str;
      description = "The public SSH key of the administrator";
      example = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFRTzZFhr6KACic0O5G1n+erg07weo+YFrC5UKCuB/py username@hostname";
    };

    secretsFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to the SOPS secrets file";
      example = ./secrets.json;
    };
  };

  config = lib.mkIf moduleCfg.enable {
    wolkenschloss.modules.server.enable = true;

    wolkenschloss.modules.server.adminPublicKey = moduleCfg.adminPublicKey;

    wolkenschloss.modules.mixins.sops.secretsFile = moduleCfg.secretsFile;

    wolkenschloss.modules.mixins.borgPullModeBackupServer.enable = lib.mkDefault true;
  };
}
