# A nix disko partition layout for BIOS systems
{}:
{
  boot = {
    type = "EF02";  # BIOS boot partition type
    size = "1M";
    # priority = 1;   # Make it first partition
    # attributes = [ 0 ];
  };
}