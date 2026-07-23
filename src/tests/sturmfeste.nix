{
  inputs,
  pkgs,
  lib,
  ...
}:

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

  globalTimeout = 600;
  qemu.forceAccel = true;

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

        # Provide enough free space for borg's additional_free_space setting.
        virtualisation.diskSize = 3 * 1024;

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
      virtualisation.diskSize = 3 * 1024;

      wolkenschloss.modules.mixins.borgPullModeBackupClient.enable = true;

      environment.etc = {
        # Add static host key
        "ssh/ssh_host_ed25519_key" = {
          source = "${otherHostKey}/other";
          mode = "0400";
        };
      };

      system.activationScripts.dummyData = {
        text = ''
          mkdir -p /etc/dummy-data

          echo -e "Tigers\nTortoises\nApes!\nWhy are you reading this?" > /etc/dummy-data/precious-animals.txt
          head -c 2M /dev/urandom > /etc/dummy-data/random-bytes.bin
        '';
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
    start_all()

    service_name = "borgbackup-job-vm_other-for-vm_other-create.service"
    timer_name = "borgbackup-job-vm_other-for-vm_other-create.timer"
    repo_path = "/var/lib/backups/vm_other"

    vm_sturmfeste.wait_for_unit(timer_name)

    # First backup run
    vm_sturmfeste.succeed(f"systemctl start {service_name}")

    # Second backup run
    vm_sturmfeste.succeed(f"systemctl start {service_name}")

    archives = vm_sturmfeste.succeed(
        "BORG_PASSCOMMAND='cat /etc/${borgRepoSecretFilePathFragment}' "
        f"borg list --short {repo_path}"
    ).splitlines()
    assert len(archives) >= 2, f"Expected at least two archives, got: {archives}"

    latest_archive = archives[-1]

    # Restore the latest archive
    restore_dir = "/tmp/restored-vm-other"
    vm_sturmfeste.succeed(f"rm -rf {restore_dir} && mkdir -p {restore_dir}")
    vm_sturmfeste.succeed(
        f"cd {restore_dir} && "
        "BORG_PASSCOMMAND='cat /etc/${borgRepoSecretFilePathFragment}' "
        f"borg extract {repo_path}::{latest_archive} --strip-components=1"
    )

    # Compare checksums
    original_hashes = set(
        vm_other.succeed(
            "b2sum /etc/dummy-data/precious-animals.txt /etc/dummy-data/random-bytes.bin"
        ).split()[0::2]
    )
    restored_hashes = set(
        vm_sturmfeste.succeed(
            f"b2sum {restore_dir}/dummy-data/precious-animals.txt "
            f"{restore_dir}/dummy-data/random-bytes.bin"
        ).split()[0::2]
    )
    assert original_hashes == restored_hashes, (
        f"Restored file hashes do not match originals: "
        f"original={original_hashes} restored={restored_hashes}"
    )
  '';
}
