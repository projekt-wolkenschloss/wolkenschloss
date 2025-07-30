{ 
  lib, 
  sshKeys,
  nixosPasswordHash,
  ...
}:
{
  # SSH configuration
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
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
