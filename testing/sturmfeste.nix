{
  inputs,
  pkgs,
  ...
}:
{
  name = "Sturmfeste NixOS Test";

  node.specialArgs = {
    inherit (inputs) sops-nix disko;
  };

  node.pkgsReadOnly = false;

  nodes = {
    vm_sturmfeste =
      {
        pkgs,
        sops-nix,
        disko,
        ...
      }:
      {

        imports = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ../modules/sturmfeste
        ];

        # Enables the Sturmfeste module
        pwks.sturmfeste = {
          enable = true;
          adminPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFRTzZFhr6KACic0O5G1n+erg07weo+YFrC5UKCuB/py username@hostname";
          secretsFile = ./sturmfeste-test/secrets.json;
        };
      };

    vm_other = { ... }: {
      imports = [
        ../modules/mixins/borg-backup/borg-pull-mode-backup-client.nix
      ];

      wolkenschloss.modules.mixins.borgPullModeBackupClient.enable = true;
    };
  };

  testScript = ''
    start_all()

    vm_other.succeed("whoami")
    vm_sturmfeste.succeed("whoami")
  '';
}
