# Creates and configures the wolke user.
# It is the default user of the Wolkenschloss hosts.
{ pkgs, ... }:
let
  username = "wolke";
  userEmail = "wolke@invalid.domain";
in
rec {
  users.groups.wolke = {
    gid = 9000;
    name = "${username}";
  };
  users.users.wolke = {
    uid = 9000;
    group = "${username}";
    home = "/home/${username}";
    createHome = true;
    isNormalUser = true;
    description = "Main Wolkenschloss user";
    extraGroups = [ "wheel" ];
  };

  home-manager.users."${username}" = {
    home.username = "${username}";
    home.homeDirectory = "${users.users.${username}.home}";
    home.stateVersion = "24.11";

    home.packages = with pkgs; [
      nnn
      zip
      unzip
      xz
      fzf
      which
      tree
      nix-output-monitor
      iotop
      btop
      iftop
    ];

    programs.home-manager.enable = true;

    programs.git = {
      enable = true;
      userName = "${username}";
      userEmail = "${userEmail}";
    };

    programs.bash = {
      enable = true;
      enableCompletion = true;
    };
  };
}
