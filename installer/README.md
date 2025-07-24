# Wolkenschloss Custom Installer

This directory contains the configurations and tools for creating custom NixOS installer ISOs with pre-configured authentication for Wolkenschloss deployment.

## Overview

The custom installer solves the fundamental problem of needing physical access to set passwords for automated deployment. It provides:

- ✅ Pre-configured root and nixos user passwords
- ✅ SSH key authentication
- ✅ Enabled SSH daemon by default
- ✅ Network configuration (DHCP/static)
- ✅ Required deployment tools pre-installed
- ✅ Wolkenschloss-specific optimizations

## Quick Start

### 1. Build a Custom Installer ISO

```bash
# Build with default configuration
./installer/build-iso.sh

# Build secure version
./installer/build-iso.sh secure

# Build with custom SSH keys
SSH_KEYS="ssh-ed25519 AAAAC3...your-key user@host" ./installer/build-iso.sh custom
```

### 2. Flash and Boot

```bash
# Flash to USB drive
sudo dd if=result/wolkenschloss-installer-*.iso of=/dev/sdX bs=4M status=progress

# Or test in QEMU
./installer/test-installer.sh --iso result/wolkenschloss-installer-*.iso ssh
```

### 3. Deploy Wolkenschloss

```bash
# SSH to the booted system
ssh root@<target-ip>

# Run nixos-anywhere for automated deployment
nix run github:nix-community/nixos-anywhere -- \
  --generate-hardware-config nixos-facter ./facter.json \
  --flake '.#your-config' \
  --target-host root@<target-ip>
```

## Configuration Files

### `base-installer.nix`
Foundation configuration with:
- Basic package set
- Network configuration
- SSH service
- Hardware support
- Performance optimizations

### `custom-installer.nix`
Adds authentication and Wolkenschloss features:
- Pre-configured passwords
- SSH key support
- Custom banner
- Deployment tools
- Helpful aliases

### `secure-installer.nix`
Production-ready configuration with:
- Strong password hashes
- Security hardening
- Firewall configuration
- AppArmor support
- Monitoring services

## Tools

### `build-iso.sh`
Main build script with support for:
- Multiple build methods (nixos-generators, manual, flake)
- Environment variable overrides
- Custom configurations
- Testing integration

**Usage:**
```bash
./installer/build-iso.sh [OPTIONS] [CONFIG]

# Examples
./installer/build-iso.sh                    # Default custom build
./installer/build-iso.sh secure             # Secure configuration
./installer/build-iso.sh --method flake     # Use flake method
./installer/build-iso.sh --test custom      # Build and test
```

### `test-installer.sh`
Comprehensive testing script:
- Build validation
- SSH connectivity tests
- Authentication tests
- Network configuration tests
- Deployment readiness tests

**Usage:**
```bash
./installer/test-installer.sh [OPTIONS] [TEST_TYPE]

# Examples
./installer/test-installer.sh ssh           # Test SSH access
./installer/test-installer.sh auth          # Test authentication
./installer/test-installer.sh deployment    # Full deployment test
```

## Environment Variables

Configure the installer build with environment variables:

```bash
# SSH keys (comma-separated)
export SSH_KEYS="ssh-ed25519 AAAAC3...key1,ssh-rsa AAAAB3...key2"

# Custom password hashes
export ROOT_PASSWORD_HASH="$6$rounds=4096$salt$hash..."
export NIXOS_PASSWORD_HASH="$6$rounds=4096$salt$hash..."

# Build with custom settings
./installer/build-iso.sh custom
```

## Password Management

### Generate Secure Password Hashes

```bash
# Method 1: Using mkpasswd (recommended)
mkpasswd -m sha-512 -R 4096 "your-secure-password"

# Method 2: Using openssl
openssl passwd -6 -salt $(openssl rand -base64 6) "your-password"

# Method 3: Using Python
python3 -c "import crypt; print(crypt.crypt('your-password', crypt.mksalt(crypt.METHOD_SHA512)))"
```

### SSH Key Management

```bash
# Generate deployment key
ssh-keygen -t ed25519 -f ~/.ssh/wolkenschloss_deployment -C "wolkenschloss-deployment"

# Get public key for configuration
cat ~/.ssh/wolkenschloss_deployment.pub
```

## Integration with Main Project

Add to your main `flake.nix`:

```nix
{
  # ... existing configuration ...
  
  packages.x86_64-linux = {
    # ... existing packages ...
    
    # Custom installer ISOs
    installer-iso-custom = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./installer/custom-installer.nix ];
    }.config.system.build.isoImage;
    
    installer-iso-secure = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./installer/secure-installer.nix ];
    }.config.system.build.isoImage;
  };
}
```

Build with: `nix build .#installer-iso-custom`

## Security Considerations

⚠️ **Important Security Notes:**

1. **Change Default Passwords**: The example configurations include default passwords for demonstration. Always change these for production use.

2. **Secure Key Storage**: Store deployment SSH keys securely and rotate them regularly.

3. **Network Security**: Consider the network environment when deploying. The installer opens SSH access.

4. **Temporary Access**: Consider changing/disabling installer credentials after deployment.

5. **Hardware Security**: Physical access to the ISO means access to embedded credentials.

## Testing

### Quick Test
```bash
# Build and test basic functionality
./installer/test-installer.sh

# Test specific features
./installer/test-installer.sh auth
./installer/test-installer.sh network
```

### Manual Testing
```bash
# Build ISO
./installer/build-iso.sh custom

# Start QEMU for manual testing
qemu-system-x86_64 \
  -enable-kvm \
  -m 2048 \
  -cdrom result/wolkenschloss-installer-*.iso \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net,netdev=net0

# Test SSH (from another terminal)
ssh -p 2222 root@localhost
```

## Troubleshooting

### Build Issues
- Ensure Nix is properly installed and configured
- Check that nixos-generators is available
- Verify configuration file syntax with `nix-instantiate --parse`

### SSH Connection Issues
- Verify the system has booted completely (wait 60+ seconds)
- Check network connectivity: `ip addr show`
- Verify SSH service: `systemctl status sshd`
- Check firewall: `iptables -L`

### Authentication Issues
- Verify password hash format
- Check SSH key format and permissions
- Test with verbose SSH: `ssh -vvv`

### Network Issues
- Check interface status: `ip link show`
- Verify DHCP client: `systemctl status dhcpcd`
- Test DNS resolution: `nslookup google.com`

## Examples

### Production Deployment Workflow

1. **Prepare credentials:**
   ```bash
   # Generate deployment key
   ssh-keygen -t ed25519 -f deployment_key
   
   # Generate password hash
   ROOT_HASH=$(mkpasswd -m sha-512 -R 4096 "secure-root-password")
   ```

2. **Build secure installer:**
   ```bash
   SSH_KEYS="$(cat deployment_key.pub)" \
   ROOT_PASSWORD_HASH="$ROOT_HASH" \
   ./installer/build-iso.sh secure
   ```

3. **Deploy to hardware:**
   ```bash
   # Flash ISO to USB
   sudo dd if=result/wolkenschloss-installer-*.iso of=/dev/sdX
   
   # Boot target hardware from USB
   # Wait for network acquisition
   
   # Deploy with nixos-anywhere
   nix run github:nix-community/nixos-anywhere -- \
     --generate-hardware-config nixos-facter ./facter.json \
     --flake '.#production-config' \
     --target-host root@<target-ip> \
     --build-on-remote
   ```

### Development Testing

```bash
# Quick build and test cycle
./installer/build-iso.sh --clean --test custom

# Test specific authentication method
SSH_KEYS="$(cat ~/.ssh/id_ed25519.pub)" \
./installer/build-iso.sh custom

./installer/test-installer.sh --iso result/wolkenschloss-installer-*.iso auth
```

## Contributing

When adding new features:

1. Update the appropriate configuration file (`base-installer.nix`, `custom-installer.nix`, or `secure-installer.nix`)
2. Test with `./installer/test-installer.sh`
3. Update this documentation
4. Consider security implications
5. Test on real hardware when possible

## References

- [NixOS Manual: Building ISOs](https://nixos.org/manual/nixos/stable/index.html#sec-building-image)
- [nixos-generators](https://github.com/nix-community/nixos-generators)
- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
- [Main Documentation](../docs/custom-installer-iso.md)
