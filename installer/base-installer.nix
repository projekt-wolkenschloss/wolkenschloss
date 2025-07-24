# Base Wolkenschloss Installer Configuration
# This provides the foundation for all custom installer ISOs

{ config, pkgs, lib, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
    <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
  ];

  # Basic system configuration
  system.stateVersion = "25.05";

  # Network configuration optimized for installer
  networking = {
    # Use predictable interface names for consistency
    usePredictableInterfaceNames = true;
    # Enable DHCP by default
    dhcpcd.enable = true;
    # Enable wireless support
    wireless.enable = true;
    # Disable NetworkManager (conflicts with wireless)
    networkmanager.enable = false;
  };

  # SSH Configuration for remote access
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      PubkeyAuthentication = true;
      # Allow empty passwords for initial setup
      PermitEmptyPasswords = false;
    };
    # Open firewall port
    openFirewall = true;
  };

  # Force SSH to start (override minimal installer default)
  systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];

  # Enhanced package set for deployment tasks
  environment.systemPackages = with pkgs; [
    # Network tools
    wget
    curl
    
    # Version control
    git
    
    # Text editors
    vim
    nano
    
    # System tools
    tmux
    screen
    htop
    
    # Debugging tools
    lsof
    strace
    
    # Disk tools
    parted
    smartmontools
    
    # Network diagnostics
    nettools
    iproute2
    dnsutils
    
    # Compression tools
    zip
    unzip
    
    # Hardware detection
    pciutils
    usbutils
    dmidecode
  ];

  # Improve installer experience
  services.getty.autologinUser = lib.mkForce "nixos";
  
  # Console configuration
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # Set timezone (can be changed during installation)
  time.timeZone = "UTC";

  # Locale settings
  i18n.defaultLocale = "en_US.UTF-8";

  # Performance tweaks for installer
  boot = {
    # Faster boot
    kernelParams = [ 
      "quiet" 
      "splash" 
      # Reduce boot time
      "systemd.show_status=false"
    ];
    
    # Support more hardware
    supportedFilesystems = [ "zfs" "btrfs" "ext4" "xfs" ];
    
    # Load common kernel modules
    kernelModules = [ 
      "kvm-intel" 
      "kvm-amd" 
    ];
  };

  # Security considerations for installer
  security = {
    # Allow sudo without password for nixos user
    sudo = {
      wheelNeedsPassword = false;
      # Allow passwordless sudo for installation tasks
      extraRules = [
        {
          users = [ "nixos" ];
          commands = [
            {
              command = "ALL";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
    };
  };

  # Hardware support
  hardware = {
    enableRedistributableFirmware = true;
    # Enable common hardware
    cpu.intel.updateMicrocode = true;
    cpu.amd.updateMicrocode = true;
  };

  # Optimization for live system
  environment.variables = {
    # Reduce memory usage
    NIXOS_CONFIG = "/etc/nixos/configuration.nix";
  };

  # Documentation 
  documentation = {
    enable = true;
    nixos.enable = true;
    man.enable = true;
  };
}
