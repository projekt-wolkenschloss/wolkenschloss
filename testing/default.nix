{ 
  nixpkgs, 
  lib, 
  disko, 
  ... 
}:

let  
  sshKey =
    if (builtins.getEnv "VM_SSH_KEY") != "" then
      builtins.getEnv "VM_SSH_KEY"
    else 
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPfdblJ4KYOY8aLSnPigAhinhAnUyXxMLsTbGmmg15YC wolkenschloss-developer-key-for-test-vms";
  nixosPasswordHash =
    if (builtins.getEnv "VM_NIXOS_PASSWORD_HASH") != "" then
      builtins.getEnv "VM_NIXOS_PASSWORD_HASH"
    else
      "$y$j9T$/sYOC0Od9Yf1OARxHgUV2.$JtFLVQ.CoUkw4mqYmLY1TFgq2C0IVvUBO278Fh2cY.3"; # test
in
{
  wlknslos-single-storage-device = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./hardware-configuration.nix
      disko.nixosModules.disko
      (import ../hardware/partitioning-layouts/single-storage-device.nix {
        inherit disko;
        inherit lib;
      })
      ( import ../hardware/partitioning-layouts/zfs-root-rollback.nix {
        inherit nixpkgs;
      })
      ./base.nix
      ./auth.nix
    ];
  };
}
