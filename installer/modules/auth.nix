{
  lib,
  sshKey,
  nixosPasswordHash,
  ...
}:

{
  assertions = [
    {
      assertion = builtins.stringLength sshKey > 0;
      message = "sshKey parameter cannot be empty";
    }
    {
      assertion = builtins.stringLength nixosPasswordHash > 0;
      message = "nixosPasswordHash cannot be empty";
    }
  ];

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
        openssh.authorizedKeys.keys = [ 
          sshKey
       ];
      };
    };
  };

  # Sudo configuration
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
}
