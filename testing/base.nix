{ 
  bootDevice ? "/dev/sda",
  ... 
}:

{
  # Source: nixos options
  system.stateVersion = "25.05";

  # Source: nixos options
  hardware = {
    enableRedistributableFirmware = true;
  };

  # Source: nixos options
  boot = {
    supportedFilesystems = [ "zfs" ];
    kernelParams = [
      "zfs_force=1"
    ];
    loader.grub = {
      zfsSupport = true;
      device = bootDevice;
    };
  };

  # Source: nixos options
  networking = {
    hostName = "nixos-testing-1";
    useDHCP = true;
    # Required by zfs
    hostId = "4a967f46";
  };

  # Source: nixos options
  virtualisation.docker.storageDriver = "overlay2";

  # Source: nixos options
  # SSH configuration
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PubkeyAuthentication = true;
      MaxAuthTries = 10;
    };
  };

  # Enable ZFS support and configure it
  services.zfs = {
    # Enables ZFS trimming, informing the storage devices about unused blocks that can be reclaimed
    trim.enable = true;
    trim.interval = "weekly";
    # Enables automatic scrubbing of ZFS pools.
    # Read more here: https://blogs.oracle.com/oracle-systems/post/disk-scrub-why-and-when
    autoScrub.enable = true;
    autoScrub.interval = "monthly";
  };
}
