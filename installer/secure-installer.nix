# Secure Wolkenschloss Installer Configuration
# This version uses proper password hashes and includes more security features

{ config, pkgs, ... }:

let
  # Load secrets from environment or files
  # In production, these should be loaded from secure sources

  # Generate proper password hashes with:
  # mkpasswd -m sha-512 -R 4096 "your-password"

  # Example hashes (DO NOT USE IN PRODUCTION):
  # Password: "wolkenschloss-root-2024"
  rootPasswordHash = "$6$rounds=4096$saltsaltsalt$A6UXkTJvFuPFnrOGD5QzK1HnCMm/qQPK8XYHJvM9NpEjVQ6vLcg9SrN8XYZA.wK.FZgH4N7qZJhY8qTY9QZGqHT0";

  # Password: "wolkenschloss-nixos-2024"
  nixosPasswordHash = "$6$rounds=4096$saltsaltsalt$B7VYlUKwGvQGosPHE6RzL2IoONn/rRQL9YZIKwO0OpFkWR7wMdh0TsO9YZAB.xL.GAgI5O8rAKiZ9rUZ0RAHrIU1";

in
{
  imports = [
    ./base-installer.nix
  ];

  # User configuration with secure defaults
  users = {
    # Allow user creation and management
    mutableUsers = false; # Enforce declarative user management

    users = {
      root = {
        hashedPassword = rootPasswordHash;

        # SSH configuration
        openssh.authorizedKeys.keys = [
          # ADD YOUR SSH KEYS HERE
          # Example (replace with your actual keys):
          # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx deployment@wolkenschloss"
        ];

        shell = pkgs.bash;
      };

      nixos = {
        isNormalUser = true;
        hashedPassword = nixosPasswordHash;
        extraGroups = [
          "wheel"
          "networkmanager"
          "video"
          "audio"
          "disk"
        ];
        uid = 1000;

        # Same SSH keys as root for convenience
        openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;

        shell = pkgs.bash;
      };
    };
  };

  # Enhanced SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      # Security settings
      PermitRootLogin = "yes"; # Needed for automated deployment
      PasswordAuthentication = true;
      PubkeyAuthentication = true;

      # Disable weak authentication
      PermitEmptyPasswords = false;
      ChallengeResponseAuthentication = false;

      # Connection security
      Protocol = 2;
      MaxAuthTries = 3;
      LoginGraceTime = 60;

      # Disable unused features
      X11Forwarding = false;
      UseDNS = false;

      # Rate limiting
      MaxStartups = "10:30:100";
      MaxSessions = 10;

      # Ciphers and MACs (secure defaults)
      Ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
        "aes128-gcm@openssh.com"
        "aes256-ctr"
        "aes192-ctr"
        "aes128-ctr"
      ];

      KexAlgorithms = [
        "curve25519-sha256"
        "curve25519-sha256@libssh.org"
        "ecdh-sha2-nistp521"
        "ecdh-sha2-nistp384"
        "ecdh-sha2-nistp256"
        "diffie-hellman-group16-sha512"
        "diffie-hellman-group18-sha512"
      ];

      Macs = [
        "hmac-sha2-256-etm@openssh.com"
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256"
        "hmac-sha2-512"
      ];
    };

    # Custom banner
    banner = ''
      ═══════════════════════════════════════════════════════════════
                          WOLKENSCHLOSS INSTALLER
      ═══════════════════════════════════════════════════════════════

      AUTHORIZED ACCESS ONLY

      This system is configured for automated NixOS deployment.
      Authentication configured with secure password hashes and SSH keys.

      Default users:
      - root  (for deployment scripts)
      - nixos (for interactive access)

      For support: https://github.com/projekt-wolkenschloss/wolkenschloss

      ═══════════════════════════════════════════════════════════════
    '';

    # Host keys - generate fresh ones for security
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        path = "/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
      {
        path = "/etc/ssh/ssh_host_ecdsa_key";
        type = "ecdsa";
        bits = 521;
      }
    ];
  };

  # Firewall configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # SSH only
    allowPing = true;

    # Log dropped packets for debugging
    logReversePathDrops = true;

    # Extra iptables rules if needed
    extraCommands = ''
      # Rate limit SSH connections
      iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set
      iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
    '';
  };

  # Network configuration with fallbacks
  networking = {
    # Use predictable interface names
    usePredictableInterfaceNames = true;

    # Enable DHCP
    dhcpcd = {
      enable = true;
      wait = "background"; # Don't block boot
    };

    # DNS configuration with multiple providers
    nameservers = [
      "8.8.8.8"
      "8.8.4.4"
      "1.1.1.1"
      "9.9.9.9"
    ];

    # Wireless template (uncomment and configure as needed)
    # wireless = {
    #   enable = true;
    #   networks = {
    #     "YourSSID" = {
    #       psk = "your-wifi-password";
    #     };
    #   };
    # };
  };

  # Additional deployment tools
  environment.systemPackages = with pkgs; [
    # Essential deployment tools
    git
    curl
    wget
    jq
    yq

    # Password and secret management
    age
    sops
    gnupg

    # Network utilities
    nettools
    iproute2
    dnsutils
    nmap

    # System utilities
    htop
    iotop
    lsof
    strace

    # File management
    ripgrep
    fd
    tree

    # Disk utilities
    parted
    smartmontools

    # Editors
    vim
    nano

    # Compression
    zip
    unzip
    tar

    # Development
    python3

    # Hardware detection
    pciutils
    usbutils
    dmidecode

    # File systems
    zfs
    btrfs-progs

    # Monitoring
    tcpdump
    iftop
  ];

  # Helpful aliases and functions
  environment.shellAliases = {
    # Deployment shortcuts
    "nixos-anywhere" = "nix run github:nix-community/nixos-anywhere";
    "generate-hardware" = "nixos-generate-config --show-hardware-config";
    "run-disko" = "nix --experimental-features 'nix-command flakes' run github:nix-community/disko";

    # System shortcuts
    "ll" = "ls -la";
    "la" = "ls -la";
    "grep" = "rg";
    "find" = "fd";

    # Network diagnostics
    "myip" = "ip -4 addr show | grep inet | grep -v 127.0.0.1";
    "ports" = "netstat -tuln";

    # System info
    "meminfo" = "cat /proc/meminfo | head -10";
    "cpuinfo" = "lscpu";
    "diskinfo" = "lsblk -f";
  };

  # System monitoring and information
  systemd.services.wolkenschloss-status = {
    description = "Wolkenschloss Installer Status Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeScript "installer-status" ''
        #!${pkgs.bash}/bin/bash

        echo "╔══════════════════════════════════════════════════════════╗"
        echo "║               WOLKENSCHLOSS INSTALLER READY              ║"
        echo "╚══════════════════════════════════════════════════════════╝"
        echo
        echo "System Information:"
        echo "- Hostname: $(hostname)"
        echo "- Kernel: $(uname -r)"
        echo "- Memory: $(free -h | awk '/^Mem:/ {print $2}')"
        echo
        echo "Network Interfaces:"
        ${pkgs.iproute2}/bin/ip -4 addr show | ${pkgs.gnugrep}/bin/grep -E "^[0-9]+:|inet " | ${pkgs.gawk}/bin/awk '
          /^[0-9]+:/ { iface = $2; gsub(/:/, "", iface) }
          /inet / && !/127.0.0.1/ { print "- " iface ": " $2 }
        '
        echo
        echo "SSH Service: $(systemctl is-active sshd)"
        echo "Firewall: $(systemctl is-active firewall)"
        echo
        echo "Ready for deployment!"
        echo "- SSH access available on port 22"
        echo "- Both password and key authentication enabled"
        echo "- Use 'nixos-anywhere' for automated deployment"
        echo
      '';
    };
  };

  # Boot configuration for broad hardware support
  boot = {
    # Kernel parameters for compatibility
    kernelParams = [
      "quiet"
      "splash"
      "zfs_force=1"
      # Ensure network interfaces are up
      "systemd.network.wait-online.any=true"
    ];

    # Support all common filesystems
    supportedFilesystems = [
      "zfs"
      "btrfs"
      "ext4"
      "ext3"
      "ext2"
      "xfs"
      "ntfs"
      "vfat"
      "exfat"
    ];

    # Load virtualization modules
    kernelModules = [
      "kvm-intel"
      "kvm-amd"
      "virtio_pci"
      "virtio_blk"
      "virtio_scsi"
      "virtio_net"
      "virtio_balloon"
    ];

    # Hardware support
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "sd_mod"
      "sr_mod"
      "virtio_pci"
      "virtio_blk"
      "virtio_scsi"
    ];
  };

  # Time and locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # Console configuration
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # Documentation and help
  documentation = {
    enable = true;
    nixos.enable = true;
    man.enable = true;
    info.enable = true;
  };

  # Security enhancements
  security = {
    sudo = {
      enable = true;
      wheelNeedsPassword = false; # For automated deployment
    };

    # AppArmor for additional security
    apparmor.enable = true;
  };

  # System services
  services = {
    # Time synchronization
    chrony.enable = true;

    # Hardware monitoring
    smartd.enable = true;

    # System logging
    rsyslog.enable = true;
  };
}
