# Nix module to enable automatic rollback of the root ZFS dataset
# via systemd service in the initrd.
{
  nixpkgs,
  rootZfsDatasetSnapshot ? "rpool/nixos/root@empty",
}:

{
  boot.initrd.systemd = {
    enable = true;
    services = {
      initrd-rollback-root = {
        description = "Rollback the root filesystem to a previous snapshot";
        after = [ "zfs-import-rpool.service" ];
        wantedBy = [ "initrd.target" ];
        before = [ "sysroot.mount" ];
        path = [ nixpkgs.zfs ];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";
        script = "zfs rollback -r ${rootZfsDatasetSnapshot}";
      };
    };
  };
}
