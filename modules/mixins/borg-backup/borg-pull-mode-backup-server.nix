{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.wolkenschloss.modules.mixins.borgPullModeBackupServer =
    let
      backupClientOptions = {
        options = {
          user = lib.mkOption {
            type = lib.types.str;
            example = "username";
            description = "User on the backup client used to log in via ssh.";
          };

          hostname = lib.mkOption {
            type = lib.types.str;
            example = "hostname";
            description = "Hostname of the backup client.";
          };

          host = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            example = "192.168.1.1";
            default = null;
            description = "Backup client host ip";
          };

          sshKeyFile = lib.mkOption {
            type = lib.types.path;
            example = "/home/user/.ssh/id_rsa";
            description = "Path to the ssh private key used for authentication when connecting to the backup client.";
          };

          additionalSshArgs = lib.mkOption {
            type = lib.types.str;
            description = "Additional ssh arguments to use when connecting to the backup client";
            default = "";
            example = "-p 22222";
          };
        };
      };

      backupJobOptions = {
        options = {
          enable = lib.mkEnableOption "Borg pull mode backup";

          borgRepoPath = lib.mkOption {
            type = lib.types.str;
            example = "/backups/hostname";
            description = "Path to the borg repository on the backup server.";
          };

          borgRepoPasswordFile = lib.mkOption {
            type = lib.types.str;
            example = "/run/secrets/borg/hostname-repo-password";
            description = "Path to the file containing the borg repository password on the backup server. This should be a file with a single line containing the password.";
          };

          pathsToBackup = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            example = [
              "/home/user/data"
              "/var/lib/someapp"
            ];
            description = "List of paths to backup on the client.";
          };

          backupSchedule = lib.mkOption {
            type = lib.types.str;
            default = "";
            example = "*-*-* 03:00:00";
            description = ''
              Systemd timer expression defining the backup schedule. 
              For example, '*-*-* 03:00:00' for daily backups at 3 AM.
              Leave empty to disable the automatic scheduling and only run the backup manually'';
          };

          backupClient = lib.mkOption {
            description = "Access configuration of the backup client used for ssh access.";
            type = lib.types.submodule backupClientOptions;
          };
        };
      };
    in
    {
      enable = lib.mkEnableOption "Allows this node to act as a Borg pull mode backup server";

      jobs = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule backupJobOptions);
        description = "List of borg pull mode backup jobs.";
        default = { };
      };
    };

  config =
    let
      moduleCfg = config.wolkenschloss.modules.mixins.borgPullModeBackupServer;
      enabledJobs = lib.filterAttrs (name: value: value.enable == true) moduleCfg.jobs;

      mkSocketPath =
        {
          hostname,
          prefix ? "/run/borg-backup",
        }:
        "${prefix}/${hostname}.sock";

      normalizeHostname =
        hostname: builtins.replaceStrings [ "." " " "/" "@" ] [ "-" "-" "-" "-" ] hostname;
      mkUnitName =
        jobName: hostname: suffix:
        "borgbackup-job-${jobName}-for-${normalizeHostname hostname}-${suffix}";

      mkServeSocketUnitName = jobName: hostname: mkUnitName jobName hostname "serve";
      mkCreateUnitName = jobName: hostname: mkUnitName jobName hostname "create";

      borgPath = "${pkgs.borgbackup}/bin/borg";

      # Creates a listening socket that spawns a borg serve process on connection
      mkServeSocket =
        { jobName, jobConfig }:
        let
          socketPath = mkSocketPath { hostname = jobConfig.backupClient.hostname; };
          unitName = mkServeSocketUnitName jobName jobConfig.backupClient.hostname;
        in
        {
          "${unitName}" = {
            enable = true;
            description = "Socat socket for the borg reverse ssh connection to ${jobConfig.backupClient.hostname}";
            listenStreams = [ "${socketPath}" ];
            partOf = [ "${unitName}@.service" ];
            wantedBy = [ "sockets.target" ];
            socketConfig = {
              Accept = "yes";
              RemoveOnStop = "yes";
            };
          };
        };

      # Creates the borg serve service that is spawned on connection to the socket
      mkServeService =
        {
          jobName,
          jobConfig,
        }:
        let
          unitName = mkServeSocketUnitName jobName jobConfig.backupClient.hostname;
        in
        {
          "${unitName}@" = {
            enable = true;
            description = "Borg backup serve process for backup of host ${jobConfig.backupClient.hostname}";
            enableStrictShellChecks = true;
            after = [
              "network-online.target"
              "${unitName}.socket"
            ];
            requires = [
              "network-online.target"
              "${unitName}.socket"
            ];
            serviceConfig = {
              ExecStart = "${borgPath} serve --append-only --restrict-to-path ${jobConfig.borgRepoPath}";
              Type = "simple";
              StandardInput = "socket";
              StandardOutput = "socket";
              StandardError = "journal";
            };
          };
        };

      # Creates the systemd timer that triggers the backup on the defined schedule
      mkCreateTimer =
        {
          jobName,
          jobConfig,
        }:
        let
          unitName = mkCreateUnitName jobName jobConfig.backupClient.hostname;
        in
        {
          "${unitName}" = {
            enable = jobConfig.backupSchedule != "";
            description = "Timer for borg backup of host ${jobConfig.backupClient.hostname}";
            wantedBy = [ "multi-user.target" ];
            requires = [
              "network-online.target"
            ];
            after = [
              "network-online.target"
              "sysinit.target"
              "time-sync.target"
              "time-set.target"
            ];
            timerConfig = {
              OnCalendar = jobConfig.backupSchedule;
              Unit = "${unitName}.service";
              Persistent = false; # Don't run missed backups immediately on boot
            };
          };
        };

      # A service unit that executes the borg backup on a schedule by connecting to the borg serve process on the backup server via reverse ssh
      mkCreateService =
        {
          jobName,
          jobConfig,
        }:
        let
          # TODO normalize?
          hostname = jobConfig.backupClient.hostname;
          unitName = mkCreateUnitName jobName hostname;
        in
        {
          "${unitName}" = {
            enable = true;
            description = "Borg backup job for host ${hostname}";
            enableStrictShellChecks = true;
            requires = [
              "network-online.target"
            ];
            environment = {
              BORG_PASSCOMMAND = "cat ${jobConfig.borgRepoPasswordFile}";
              BORG_RELOCATED_REPO_ACCESS_IS_OK = "yes";
            };
            serviceConfig =
              let
                repoPath = jobConfig.borgRepoPath;
                serverSocketPath = mkSocketPath { hostname = hostname; };
                clientSocketPath = mkSocketPath {
                  hostname = "borg-backup-${hostname}";
                  prefix = "/tmp";
                };
                backupPathsAsString = lib.concatStringsSep " " jobConfig.pathsToBackup;
                sshTargetHost =
                  if jobConfig.backupClient.host != null then jobConfig.backupClient.host else hostname;

                serviceScript = pkgs.writeShellScript "borg-backup-create" ''
                  set -eo pipefail
                  if ! ${borgPath} list ${repoPath} > /dev/null; then
                    echo "Repo ${repoPath} needs initialization"
                    mkdir -p ${dirOf repoPath}
                    ${borgPath} init --encryption=repokey-blake2 ${repoPath}

                    # Tries to prevent the disk from filling up completely. In that case, borg cannot even delete
                    # old archives anymore. See also https://borgbackup.readthedocs.io/en/stable/quickstart.html#important-note-about-free-space
                    ${borgPath} config ${repoPath} additional_free_space 2G
                    echo "Initialized borg repo at ${repoPath}"
                  fi

                  ARCHIVE_NAME="${hostname}-$(date -Iseconds)"

                  echo "Creating new borg backup archive: $ARCHIVE_NAME"
                  set +e
                  ${pkgs.openssh}/bin/ssh -o ExitOnForwardFailure=yes -o StreamLocalBindUnlink=yes \
                    -i ${jobConfig.backupClient.sshKeyFile} -o StrictHostKeyChecking=accept-new \
                    ${jobConfig.backupClient.additionalSshArgs} \
                    -R ${clientSocketPath}:${serverSocketPath} \
                    ${jobConfig.backupClient.user}@${sshTargetHost} sudo BORG_PASSCOMMAND=\"cat ${jobConfig.borgRepoPasswordFile}\" BORG_RELOCATED_REPO_ACCESS_IS_OK=yes borg \
                    -v --rsh \"sh -c \'exec socat STDIO UNIX-CONNECT:${clientSocketPath}\'\" \
                    create --compression auto,zstd,9 --stats --checkpoint-interval 600 --show-rc \
                    ssh://server/${repoPath}::"$ARCHIVE_NAME".failure \
                    ${backupPathsAsString}
                  RC=$?
                  set -e

                  if [ $RC -gt 1 ]; then
                    echo "Backup of host ${hostname} failed with exit code $RC"
                    exit 1
                  else
                    ${borgPath} rename "${repoPath}::$ARCHIVE_NAME.failure" "$ARCHIVE_NAME"
                  fi

                  echo "Pruning and compacting old borg backup archives"
                  ${borgPath} prune \
                    --list --stats \
                    --keep-daily=7 --keep-weekly=12 --keep-monthly=12 \
                    ${repoPath}
                    
                  ${borgPath} compact ${repoPath}
                  echo "Backup of host ${hostname} completed successfully"
                '';
              in
              {
                Type = "oneshot";
                ExecStart = serviceScript;
              };
          };
        };

      forEachJob =
        fn: lib.concatMapAttrs (jobName: jobConfig: fn { inherit jobName jobConfig; }) enabledJobs;
    in
    lib.mkIf moduleCfg.enable {

      environment.systemPackages = with pkgs; [
        openssh
        borgbackup
        socat
      ];

      systemd.sockets = forEachJob mkServeSocket;

      systemd.timers = forEachJob mkCreateTimer;

      systemd.services = (forEachJob mkServeService) // (forEachJob mkCreateService);
    };
}
