{
  config,
  lib,
  nixpkgs,
  ...
}:

let
  zfsCompatibleKernelPackages = lib.filterAttrs (
    name: kernelPackages:
      (builtins.match "linux_[0-9]+_[0-9]+" name) != null
        && (builtins.tryEval kernelPackages).success
        && (!kernelPackages.${config.boot.zfs.package.kernelModuleAttribute}.meta.broken)
  ) nixpkgs.linuxKernel.packages;

  # Tries to find the latest ZFS-compatible Kernel currently available
  latestKernelPackage = lib.last (
    lib.sort (a: b: (lib.versionOlder a.kernel.version b.kernel.version)) (
      builtins.attrValues zfsCompatibleKernelPackages
    )
  );
in
{
  boot.kernelPackages = latestKernelPackage;

  # Enable ZFS support
  boot.supportedFilesystems = [ "zfs" ];
  
  # Ensure ZFS modules are loaded in initrd
  boot.initrd.availableKernelModules = [ "zfs" ];
  boot.initrd.kernelModules = [ "zfs" ];
  
  # Include ZFS in the system
  environment.systemPackages = with nixpkgs; [
    zfs
    zfstools
  ];

  boot.kernelModules = [ "zfs" ];

  # ZFS requires networking.hostId to be set
  networking.hostId = "4a967f47";
}
