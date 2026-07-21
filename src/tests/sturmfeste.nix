{
  inputs,
  pkgs,
  lib,
  wolkenschlossTestLib,
  ...
}:

# TODO:
# - Find out why the VM drive is only 1 GB even though it is set to 3 GB
# - Iterate, until the backup job passes
# - Remove TODOs
# - Add pre-push hook for TODO checks
# - Restore backups
# - Verify contents
let
  borgRepoSecretFilePathFragment = "dummy-secrets/borg-repo-password";

  mkSshKeyPair =
    name:
    (pkgs.runCommand "create-ssh-key-pairs"
      {
        buildInputs = [ pkgs.openssh ];
      }
      ''
        ssh-keygen -t ed25519 -C "${name}. ONLY FOR TESTS. PUBLIC. DO NOT USE" -q -N "" -f ${name}
        mkdir -p $out
        chmod 0400 ${name} ${name}.pub
        mv ${name} ${name}.pub $out
      ''
    );

  sturmfesteHostKey = mkSshKeyPair "sturmfeste";
  otherHostKey = mkSshKeyPair "other";
in
{
  name = "Sturmfeste NixOS Test";

  node.specialArgs = {
    inherit (inputs) sops-nix disko;
  };

  # globalTimeout = 600;
  qemu.forceAccel = true;
  sshBackdoor.enable = true;
  enableDebugHook = true;

  extraPythonPackages = p: [
    wolkenschlossTestLib
  ];

  node.pkgsReadOnly = false;

  defaults = {
    console.keyMap = "de";
    time.timeZone = "Europe/Berlin";
    environment.etc."${borgRepoSecretFilePathFragment}".text = "test";

    # Prevent host key generation
    services.openssh.hostKeys = lib.mkForce [ ];
  };

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

        # Allows ssh backdoor during testing
        services.openssh.settings.PermitEmptyPasswords = lib.mkForce true;
        services.openssh.settings.PermitRootLogin = lib.mkForce "yes";

        environment.etc = {
          "ssh/ssh_host_ed25519_key" = {
            source = "${sturmfesteHostKey}/sturmfeste";
            mode = "0400";
          };
        };

        # Enables the Sturmfeste module
        pwks.sturmfeste = {
          enable = true;
          adminPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFRTzZFhr6KACic0O5G1n+erg07weo+YFrC5UKCuB/py username@hostname";
          secretsFile = ./sturmfeste/secrets.json;
        };

        # Not yet configured and fails
        wolkenschloss.modules.mixins.grafanaAlloyAgent.enable = false;

        # Prevent new host dialogs
        services.openssh.knownHosts."vm_other".publicKeyFile = "${otherHostKey}/other.pub";

        # Password is "test"
        wolkenschloss.modules.mixins.nixosAdminUser.user.hashedPassword =
          "$1$.QSlejLZ$lO3iuu29I5ZYh9n7Dss0Q1";

        # Configure a backup job
        wolkenschloss.modules.mixins.borgPullModeBackupServer.jobs.vm_other = {
          enable = true;
          borgRepoPath = "/var/lib/backups/vm_other";
          borgRepoPasswordFilePath = "/etc/${borgRepoSecretFilePathFragment}";
          backupSchedule = "*-*-* 03:00:00";
          pathsToBackup = [
            "/etc/dummy-data"
          ];
          backupClient = {
            user = "herbert";
            hostname = "vm_other";
            sshKeyFile = "/etc/ssh/ssh_host_ed25519_key";
            borgRepoPasswordFilePath = "/etc/${borgRepoSecretFilePathFragment}";
          };
        };

      };

    vm_other = { pkgs, ... }: {
      imports = [
        ../../modules/mixins/borg-backup/borg-pull-mode-backup-client.nix
      ];

      # Needed for free disk size check in borg config
      # TODO test free disk size setting failure
      virtualisation.diskSize = 3 * 1024;

      wolkenschloss.modules.mixins.borgPullModeBackupClient.enable = true;

      environment.etc = {
        # Add static host key
        "ssh/ssh_host_ed25519_key" = {
          source = "${otherHostKey}/other";
          mode = "0400";
        };
        # Add test data
        "dummy-data/precious-animals.txt".source = ./wolkenschloss_tests/test-data/precious-animals.txt;
        "dummy-data/random-bytes.bin".source = ./wolkenschloss_tests/test-data/random-bytes.bin;
      };

      users.users."herbert" = {
        isNormalUser = true;
        # Password is "test"
        hashedPassword = "$1$.QSlejLZ$lO3iuu29I5ZYh9n7Dss0Q1";
        openssh.authorizedKeys.keyFiles = [
          "${sturmfesteHostKey}/sturmfeste.pub"
        ];
      };

      security.sudo.extraConfig = ''
        herbert ALL=(root:root) NOPASSWD:SETENV: ${pkgs.borgbackup}/bin/borg
        herbert ALL=(root:root) NOPASSWD:SETENV: /run/current-system/sw/bin/borg
      '';
    };
  };

  testScript = ''
    # TODO add wait conditions
    start_all()

    hashed_animals = vm_other.succeed("cksum -a sha3 --length 512 --untagged /etc/dummy-data/precious-animals.txt").split(" ")[0]
    hashed_bytes = vm_other.succeed("cksum -a sha3 --length 512 --untagged /etc/dummy-data/random-bytes.bin").split(" ")[0]

    service_name_base : str = "borgbackup-job-vm_other-for-vm_other" 
    backup_create_unit_info = vm_sturmfeste.get_unit_info(f"{service_name_base}-create.service")
    vm_sturmfeste.start_job(f"{service_name_base}-create.service")




    service_name = "borgbackup-test-vm-2-local-create.service"
    timer_name = "borgbackup-test-vm-2-local-create.timer"
    repo_path = "/tank1/backups/test-vm-2"

    # print("Checking systemd units")
    # result = vm_1_client.run(f"systemctl is-active {timer_name}")
    # assert result.exit_code == 0
    # assert result.stdout.strip() == "active"

    # # Check that the backup create service has not run yet
    # result = vm_1_client.run(f"journalctl -u {timer_name} -b --no-pager")
    # assert len(result.stdout.splitlines()) == 1
  '';
}
