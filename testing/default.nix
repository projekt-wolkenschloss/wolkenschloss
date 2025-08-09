{ nixpkgs, disko, ... }:

let
  diskId = "/dev/sda";
  
  sshKey =
    assert (builtins.stringLength (builtins.getEnv "VM_SSH_KEY") > 0);
    builtins.getEnv "VM_SSH_KEY";
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
        bootDeviceId = diskId;
      })
      ./base.nix
      ./auth.nix
    ];
  };
}
