{
  config,
  lib,
  ...
}:

let
  moduleConfig = config.wolkenschloss.modules.mixins.nixosAdminUser;
in
{
  options.wolkenschloss.modules.mixins.nixosAdminUser = {
    enable = lib.options.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Creates a nixos admin user with sudo privileges.";
    };

    user = lib.options.mkOption {
      type = lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "nixos";
            example = "nixos";
            description = "Name of the user";
          };

          sshPublicKeys = lib.mkOption {
            type = lib.types.listOf lib.types.nonEmptyStr;
            example = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFRTzZFhr6KACic0O5G1n+erg07weo+YFrC5UKCuB/py username@hostname"
            ];
            description = "The public ssh keys of the user";
          };

          hashedPassword = lib.mkOption {
            type = lib.types.nullOr lib.types.nonEmptyStr;
            description = "Whether a hashed password for the user should be set. Needs a sops secrets entry `users/<name>/hashed_password`";
            default = null;
          };
        };
      };
      default = {
        name = "nixos";
        sshPublicKeys = [ ];
      };
      example = ''
        {
          name = "nixos"
          sshPublicKeys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFRTzZFhr6KACic0O5G1n+erg07weo+YFrC5UKCuB/py username@hostname"
          ]; 
        };
      '';
    };
  };

  config = lib.mkIf moduleConfig.enable {
    assertions = [
      {
        assertion = builtins.elem "@wheel" config.nix.settings.trusted-users;
        message = "The wheel group must be in the list of nix trusted users when wolkenschloss.nixosAdminUser is enabled.";
      }
    ];

    users = {
      users = {
        "${moduleConfig.user.name}" = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
          ];
          hashedPassword = moduleConfig.user.hashedPassword;

          openssh.authorizedKeys.keys = moduleConfig.user.sshPublicKeys;
        };
      };
    };

    security.sudo = {
      enable = true;
      # Allow password-less sudo from wheel users
      wheelNeedsPassword = false;
    };

    services.openssh.settings.AllowUsers = [ "${moduleConfig.user.name}" ];
  };
}
