# Configures sops-nix to manage secrets using sops and age
{
  config,
  lib,
  ...
}:

let
  moduleConfig = config.wolkenschloss.modules.mixins.sops;
in
{
  options.wolkenschloss.modules.mixins.sops = {
    enable = lib.mkEnableOption "Whether to enable sops-nix for managing secrets.";

    secretsFile = lib.mkOption {
      type = lib.types.path;
      example = ./secrets.yaml;
      description = "Path to the sops secrets file.";
    };
  };

  config = lib.mkIf moduleConfig.enable {
    sops = {
      # Where sops will look for the secrets file by default
      defaultSopsFile = moduleConfig.secretsFile;
      age = {
        # This will automatically import SSH keys as age keys
        sshKeyPaths = [
          "/etc/ssh/ssh_host_ed25519_key"
        ];
        # Generate a new key if the key specified above does not exist
        generateKey = true;
      };
    };
  };
}
