# Custom NixOS Installer ISO with Pre-configured Authentication

This document describes how to create a customized NixOS installer ISO with predefined users, passwords, and SSH keys for unattended deployment.

## Problem Statement

Standard NixOS installer ISOs come with:

- No root password (requires manual `passwd` command)  
- Empty `nixos` user password
- No pre-configured SSH keys
- Requires physical access for initial setup

For automated/unattended deployment, we need:

- Known root password or SSH key access
- SSH server enabled by default
- Consistent authentication across deployments

## Solution Overview

We create custom NixOS installer ISOs that include:
1. Pre-configured root user with known password
2. SSH keys for passwordless access  
3. Enabled SSH daemon
4. Optional: Custom nixos user configuration
5. Network configuration options

## Implementation Methods

### Method 1: Using nixos-generators (Recommended)

`nixos-generators` is the simplest way to create custom ISOs with pre-configured authentication.

#### Installation
```bash
# Install nixos-generators
nix-env -f https://github.com/nix-community/nixos-generators/archive/master.tar.gz -i

# Or run directly
nix run github:nix-community/nixos-generators -- --help
```

#### Basic Custom ISO Configuration

Create `custom-installer.nix`:
```nix
{ config, pkgs, ... }: {
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
    <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
  ];

  # Set a known root password (for SSH access)
  users.users.root = {
    # Password: "wolkenschloss" (change this!)
    hashedPassword = "$6$rounds=4096$D8h7Qp3.$vK8EhzSc8uqDY0X8Nw7zGqzWlX9yZ4jL2Q4jYzJQrXkKrTtNpGjqxKkLqQ1Qx8CxRrZzGgGhEjGqWqDd1A.";
  };

  # Configure SSH access
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  # Ensure SSH starts at boot
  systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];

  # Optional: Add SSH keys for passwordless access
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx your-key@your-machine"
  ];

  # Network configuration - enable predictable interface names
  networking = {
    usePredictableInterfaceNames = true;
    dhcpcd.enable = true;
  };
}
```

#### Generate the ISO
```bash
nixos-generate -f iso -c custom-installer.nix
```

### Method 2: Manual ISO Building

#### Create Configuration File

Create `custom-iso.nix`:
```nix
{ config, pkgs, lib, ... }: {
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
    <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
  ];

  # Root user with known password and SSH key
  users.users.root = {
    hashedPassword = "$6$rounds=4096$YourSalt$YourHashedPassword";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx your-deployment-key"
    ];
  };

  # Nixos user (for GUI access if using graphical installer)
  users.users.nixos = {
    hashedPassword = "$6$rounds=4096$YourSalt$YourHashedPassword";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx your-deployment-key"
    ];
  };

  # SSH configuration  
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      PubkeyAuthentication = true;
    };
  };
  
  # Force SSH to start (override minimal config)
  systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];

  # Network improvements
  networking = {
    wireless.enable = true;
    networkmanager.enable = false; # conflicts with wireless
  };

  # Additional tools for deployment
  environment.systemPackages = with pkgs; [
    wget
    curl
    git
    vim
    tmux
  ];
}
```

#### Build the ISO
```bash
nix-build '<nixpkgs/nixos>' -A config.system.build.isoImage -I nixos-config=custom-iso.nix
```

### Method 3: Flake-based Approach

Create `flake.nix`:
```nix
{
  description = "Custom Wolkenschloss installer ISO";
  
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  
  outputs = { self, nixpkgs }: {
    nixosConfigurations.installer = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, modulesPath, ... }: {
          imports = [ 
            (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
          ];
          
          # Custom authentication
          users.users.root = {
            hashedPassword = "$6$wolkenschloss$hash...";
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxx deployment-key"
            ];
          };
          
          services.openssh = {
            enable = true;
            settings.PermitRootLogin = "yes";
          };
          
          systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];
        })
      ];
    };
  };
}
```

Build with:
```bash
nix build .#nixosConfigurations.installer.config.system.build.isoImage
```

## Password Generation

### Generate Hashed Passwords
```bash
# Method 1: Using mkpasswd
mkpasswd -m sha-512 -R 4096

# Method 2: Using openssl  
openssl passwd -6 -salt $(openssl rand -base64 6)

# Method 3: Using python
python3 -c "import crypt; print(crypt.crypt('your-password', crypt.mksalt(crypt.METHOD_SHA512)))"
```

### Example Passwords
```bash
# Password: "wolkenschloss"
# Hash: $6$rounds=4096$salt$hash...
```

## SSH Key Management

### Generate Deployment Keys
```bash
# Generate dedicated deployment key
ssh-keygen -t ed25519 -f ~/.ssh/wolkenschloss_deployment -C "wolkenschloss-deployment"

# Get public key
cat ~/.ssh/wolkenschloss_deployment.pub
```

### Security Considerations
- Use different passwords for different environments
- Store deployment keys securely
- Consider using SSH certificates for better key management
- Rotate credentials regularly

## Network Configuration Options

### DHCP (Default)
```nix
networking.dhcpcd.enable = true;
```

### Static IP
```nix
networking = {
  usePredictableInterfaceNames = false;
  interfaces.eth0.ipv4.addresses = [{
    address = "192.168.1.100";
    prefixLength = 24;
  }];
  defaultGateway = "192.168.1.1";
  nameservers = [ "8.8.8.8" "8.8.4.4" ];
};
```

### WiFi Support
```nix
networking.wireless = {
  enable = true;
  networks = {
    "YourSSID" = {
      psk = "your-wifi-password";
    };
  };
};
```

## Usage Examples

### Boot and SSH Access
1. Flash ISO to USB drive
2. Boot target machine
3. Wait for network acquisition
4. SSH to the machine:
   ```bash
   ssh root@<ip-address>
   # No password prompt if using SSH keys
   # Or enter the pre-configured password
   ```

### Automated Deployment Script
```bash
#!/bin/bash
# Get IP from DHCP or use static
TARGET_IP="192.168.1.100"

# Verify SSH access
ssh -o ConnectTimeout=10 root@$TARGET_IP "echo 'SSH access confirmed'"

# Run nixos-anywhere or manual installation
nix run github:nix-community/nixos-anywhere -- \
  --generate-hardware-config nixos-facter ./facter.json \
  --flake '.#your-config' \
  --target-host root@$TARGET_IP
```

## Integration with Wolkenschloss

The custom installer ISO should be integrated into the Wolkenschloss build system:

```nix
# In flake.nix outputs
packages.x86_64-linux.installer-iso = nixos-generators.nixosGenerate {
  system = "x86_64-linux";
  format = "iso";
  modules = [
    ./installer/custom-installer.nix
    # Include Wolkenschloss-specific configuration
  ];
};
```

## Security Notes

⚠️ **Important Security Considerations:**

1. **Change default passwords** - Never use the examples in production
2. **Secure key storage** - Keep deployment keys in secure locations
3. **Network security** - Consider the network environment when configuring access
4. **Temporary access** - Consider disabling/changing credentials after initial deployment
5. **Audit trail** - Log deployment activities for security auditing

## Testing

Test the custom ISO in:
1. Virtual machines (QEMU/VirtualBox)
2. Different hardware configurations
3. Various network environments
4. Both UEFI and BIOS boot modes

## Troubleshooting

### SSH Connection Issues
- Check if SSH service is running: `systemctl status sshd`
- Verify network connectivity: `ip addr show`
- Check firewall rules: `iptables -L`

### Password Authentication Issues
- Verify hashed password format
- Check SSH configuration allows password auth
- Test password with `su` command locally

### Network Issues
- Check interface names: `ip link show`
- Verify DHCP client: `systemctl status dhcpcd`
- Test DNS resolution: `nslookup google.com`

## References

- [NixOS Manual: Building a NixOS (Live) ISO](https://nixos.org/manual/nixos/stable/index.html#sec-building-image)
- [nixos-generators Documentation](https://github.com/nix-community/nixos-generators)
- [NixOS Wiki: Creating a NixOS live CD](https://nixos.wiki/wiki/Creating_a_NixOS_live_CD)
- [nixos-anywhere Documentation](https://github.com/nix-community/nixos-anywhere)
