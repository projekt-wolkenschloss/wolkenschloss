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
            type = lib.types.str;
            default = "nixos";
            example = "nixos";
            description = "Name of the user";
          };

          sshPublicKey = lib.mkOption {
            type = lib.types.str;
            example = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFRTzZFhr6KACic0O5G1n+erg07weo+YFrC5UKCuB/py username@hostname";
            description = "The public ssh key of the user";
          };

          withHashedPassword = lib.mkEnableOption "Whether a hashed password for the user should be set. Needs a sops secrets entry `users/<name>/hashed_password`";
        };
      };
      default = {
        name = "nixos";
        sshPublicKey = "";
      };
      example = ''
        {
          name = "nixos"
          sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFRTzZFhr6KACic0O5G1n+erg07weo+YFrC5UKCuB/py username@hostname" 
        };
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf moduleConfig.enable {
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
          }
          // lib.optionalAttrs (moduleConfig.user.sshPublicKey != "") {
            openssh.authorizedKeys.keys = [
              "${moduleConfig.user.sshPublicKey}"
            ];
          };
        };
      };

      security.sudo = {
        enable = true;
        # Allow passwordless sudo from wheel users
        wheelNeedsPassword = false;
      };

      services.openssh.settings.AllowUsers = [ "${moduleConfig.user.name}" ];

    })
    (
      let
        sopsUserPassRef = "users/nixos/hashed_password";
      in
      lib.mkIf (moduleConfig.enable && moduleConfig.user.withHashedPassword) {
        assertions = [
          {
            assertion = config.sops.secrets."${sopsUserPassRef}".path != null;
            message = "You must define a hashed user password in the sops secrets file with key ${sopsUserPassRef}";
          }
        ];
        sops.secrets."${sopsUserPassRef}" = { };
        users.users."${moduleConfig.user.name}".hashedPasswordFile =
          config.sops.secrets."${sopsUserPassRef}".path;
      }
    )
  ];
}
