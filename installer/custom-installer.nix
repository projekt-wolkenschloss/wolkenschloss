# Wolkenschloss Custom Installer with Pre-configured Authentication
# This builds on base-installer.nix to add authentication and Wolkenschloss-specific features

{ config, pkgs, lib, ... }:

let
  # Default credentials - CHANGE THESE FOR PRODUCTION!
  defaultRootPassword = "wolkenschloss123";
  defaultNixosPassword = "nixos123";
  
  # Generate password hash
  # You can generate this with: mkpasswd -m sha-512 -R 4096
  rootPasswordHash = "$6$rounds=4096$wolkenschloss$5K8V6JZz1tZz5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t";
  nixosPasswordHash = "$6$rounds=4096$nixos$3K8V6JZz1tZz5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t5t";
  
  # SSH keys for deployment - ADD YOUR KEYS HERE
  deploymentKeys = [
    # Example key - replace with your actual deployment key
    # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx wolkenschloss-deployment"
    
    # You can add multiple keys for different users/purposes
    # "ssh-rsa AAAAB3NzaC1yc2EAAAADAQAB... admin@wolkenschloss"
  ];

in {
  imports = [
    ./base-installer.nix
  ];

  # Root user configuration
  users.users.root = {
    # Set hashed password for SSH access
    hashedPassword = rootPasswordHash;
    
    # SSH keys for passwordless access
    openssh.authorizedKeys.keys = deploymentKeys;
    
    # Ensure root can login
    shell = pkgs.bash;
  };

  # Nixos user configuration (for GUI/console access)
  users.users.nixos = {
    # Set password for local access
    hashedPassword = nixosPasswordHash;
    
    # SSH keys for remote access
    openssh.authorizedKeys.keys = deploymentKeys;
    
    # Maintain existing nixos user properties
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    uid = 1000;
  };

  # Enhanced SSH configuration for deployment
  services.openssh = {
    settings = {
      # Security settings
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      PubkeyAuthentication = true;
      AuthorizedKeysFile = ".ssh/authorized_keys";
      
      # Performance settings
      UseDNS = false;
      X11Forwarding = false;
      
      # Connection settings
      MaxAuthTries = 3;
      LoginGraceTime = 30;
      
      # Prevent brute force (though this is a live system)
      MaxStartups = "10:30:100";
    };
    
    # Custom banner
    banner = ''
      
      ╔══════════════════════════════════════════════════════════╗
      ║                   WOLKENSCHLOSS INSTALLER                ║
      ║                                                          ║
      ║  This is a custom NixOS installer with pre-configured    ║
      ║  authentication for automated deployment.                ║
      ║                                                          ║
      ║  Default credentials (CHANGE IN PRODUCTION):             ║
      ║  - root: ${defaultRootPassword}                                    ║
      ║  - nixos: ${defaultNixosPassword}                                     ║
      ║                                                          ║
      ║  SSH keys: ${toString (builtins.length deploymentKeys)} deployment key(s) loaded                  ║
      ║                                                          ║
      ║  Ready for nixos-anywhere or manual installation        ║
      ╚══════════════════════════════════════════════════════════╝
      
    '';
  };

  # Wolkenschloss-specific installer tools
  environment.systemPackages = with pkgs; [
    # Additional tools for Wolkenschloss deployment
    jq
    yq
    age
    sops
    
    # Networking tools
    nmap
    tcpdump
    
    # Development tools (for debugging)
    python3
    
    # Disk management
    zfs
    btrfs-progs
    
    # Monitoring
    iotop
    
    # Text processing
    ripgrep
    fd
  ];

  # Network configuration suitable for most environments
  networking = {
    # Keep interfaces predictable
    usePredictableInterfaceNames = true;
    
    # Enable both DHCP and manual configuration capabilities
    dhcpcd.enable = true;
    
    # Wireless configuration template (commented out by default)
    # wireless.networks = {
    #   "YourWiFiSSID" = {
    #     psk = "your-wifi-password";
    #   };
    # };
    
    # DNS fallback
    nameservers = [ "8.8.8.8" "8.8.4.4" "1.1.1.1" ];
    
    # Enable firewall but allow SSH
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
      # Allow ping
      allowPing = true;
    };
  };

  # Additional services for deployment
  services = {
    # Enable DHCP client
    dhcpcd.enable = true;
    
    # Time synchronization
    chrony.enable = true;
  };

  # Boot configuration for compatibility
  boot = {
    # Support common file systems
    supportedFilesystems = [ "zfs" "btrfs" "ext4" "xfs" "ntfs" "vfat" ];
    
    # Common kernel modules
    kernelModules = [ 
      "kvm-intel" 
      "kvm-amd"
      "virtio_pci"
      "virtio_blk"
      "virtio_scsi"
      "virtio_net"
    ];
    
    # Enable ZFS support
    kernelParams = [ "zfs_force=1" ];
  };

  # Installation helpers
  environment.shellAliases = {
    # Quick deployment commands
    "wolke-deploy" = "nix run github:nix-community/nixos-anywhere";
    "wolke-hw" = "nixos-generate-config --show-hardware-config";
    "wolke-disko" = "nix --experimental-features 'nix-command flakes' run github:nix-community/disko";
    
    # Useful shortcuts
    "ll" = "ls -la";
    "la" = "ls -la";
    "l" = "ls -l";
    "grep" = "rg";
    "find" = "fd";
  };

  # Motd with instructions
  users.motd = ''
    Welcome to Wolkenschloss Custom Installer!
    
    This system is ready for automated deployment with:
    - Pre-configured SSH access
    - Root password: ${defaultRootPassword}
    - Nixos password: ${defaultNixosPassword}
    - SSH keys: ${toString (builtins.length deploymentKeys)} loaded
    
    Quick start:
    1. Check network: ip addr
    2. Test SSH: ssh root@<this-ip>
    3. Clone repo: git clone https://github.com/projekt-wolkenschloss/wolkenschloss.git
    4. Deploy with nixos-anywhere or run manual installation
    
    For help: man nixos-install
  '';

  # System information service
  systemd.services.wolkenschloss-info = {
    description = "Wolkenschloss Installer Information";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeScript "show-info" ''
        #!${pkgs.bash}/bin/bash
        echo "Wolkenschloss Installer Ready"
        echo "System IP addresses:"
        ${pkgs.iproute2}/bin/ip -4 addr show | ${pkgs.gnugrep}/bin/grep inet | ${pkgs.gnugrep}/bin/grep -v 127.0.0.1
        echo "SSH access available on port 22"
        echo "Ready for deployment!"
      '';
    };
  };
}
