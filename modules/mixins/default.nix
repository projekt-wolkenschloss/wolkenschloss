{
  ...
}:

{
  imports = [
    ./nixos-admin-user.nix
    ./nix.nix
    ./swap-file.nix
    ./disable-sleep-and-hibernation.nix
    ./cpu-performance-scaling.nix
    ./sops.nix
    ./grafana-alloy-agent
    ./smartctl-storage-monitoring.nix
    ./ssh-hardening.nix
    ./borg-backup
  ];
}
