{
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    inputs.wolkenschloss.nixosModules.sturmfeste
  ];

  # Don't change this
  system.stateVersion = "25.11";

  boot.loader.systemd-boot.enable = true;

  # Enables the Sturmfeste module
  pwks.sturmfeste = {
    enable = true;
    adminPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFRTzZFhr6KACic0O5G1n+erg07weo+YFrC5UKCuB/py username@hostname";
    secretsFile = ./secrets.json;
  };

  # Configures partitioning for the root device when using Disko with nixos-anywhere for declarative partitioning.
  wolkenschloss.modules.disko.simpleExt4 = {
    enable = true;
    rootDevice = "/dev/nvme0n1";
  };
}
