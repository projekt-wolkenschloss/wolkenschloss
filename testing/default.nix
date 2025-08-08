{ nixpkgs, disko, ... }:

let
  diskId = "/dev/disk/by-id/scsi-0QEMU_QUEMU_HARDDISK_drive-scsi0";
in
{
  wlknslos-single-storage-device = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./base.nix
      disko.nixosModules.disko
      (import ../hardware/partitioning-layouts/single-storage-device.nix {
        inherit disko;
        bootDeviceId = diskId;
      })
    ];
  };
}
