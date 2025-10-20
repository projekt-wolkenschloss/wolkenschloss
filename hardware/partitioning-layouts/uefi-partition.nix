# A nix disko partition layout for UEFI systems
{ }:

{
  # EFI System Partition (ESP)
  esp = {
    label = "ESP";
    # sgdisk-specific short code
    type = "EF00";
    size = "1G";
    content = {
      type = "filesystem";
      format = "vfat";
      mountpoint = "/boot";
      mountOptions = [
        "defaults"
      ];
    };
  };
}
