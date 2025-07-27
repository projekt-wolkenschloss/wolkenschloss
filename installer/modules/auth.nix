{ lib, ... }:

let
  # Environment variables with fallbacks
  sshKeys = lib.splitString "," (builtins.getEnv "SSH_KEYS");
  nixosPasswordHash =
    if (builtins.getEnv "NIXOS_PASSWORD_HASH") != "" then
      builtins.getEnv "NIXOS_PASSWORD_HASH"
    else
      "$y$j9T$/sYOC0Od9Yf1OARxHgUV2.$JtFLVQ.CoUkw4mqYmLY1TFgq2C0IVvUBO278Fh2cY.3"; # test
in
{
  # SSH configuration
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      PubkeyAuthentication = true;
      MaxAuthTries = 10;
    };
  };

  # User configuration
  users = {
    mutableUsers = false;
    users = {
      nixos = {
        isNormalUser = true;
        hashedPassword = nixosPasswordHash;
        extraGroups = [
          "wheel"
          "networkmanager"
        ];
        openssh.authorizedKeys.keys = lib.filter (key: key != "") sshKeys;
      };
    };
  };

  # Sudo configuration
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
}
