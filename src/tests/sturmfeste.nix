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

  globalTimeout = 600;
  qemu.forceAccel = true;

  extraPythonPackages = p: [
    (p.callPackage ./package.nix { })
  ];

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
          ../../modules/sturmfeste
        ];

        # Enables the Sturmfeste module
        pwks.sturmfeste = {
          enable = true;
          adminPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFRTzZFhr6KACic0O5G1n+erg07weo+YFrC5UKCuB/py username@hostname";
          secretsFile = ./sturmfeste/secrets.json;
        };
      };

    vm_other = { ... }: {
      imports = [
        ../../modules/mixins/borg-backup/borg-pull-mode-backup-client.nix
      ];

      wolkenschloss.modules.mixins.borgPullModeBackupClient.enable = true;

      # Add test data
      environment.etc = {
        "dummy-data/precious-animals.txt".source = ./sturmfeste/test-data/precious-animals.txt;
        "dummy-data/random-bytes.bin".source = ./sturmfeste/test-data/random-bytes.bin;
      };
    };
  };

  testScript = ''
    from wolkenschloss_tests import sturmfeste

    sturmfeste.start(vm_sturmfeste=machine1, vm_other=machine2)
  '';
}
