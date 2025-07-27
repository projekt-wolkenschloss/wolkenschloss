# Wolkenschloss Custom Installer

This directory contains the configurations and tools for creating custom NixOS installer ISOs with pre-configured authentication for Wolkenschloss deployment.

## Overview

The custom installer solves the fundamental problem of needing physical access to set passwords for automated deployment. It provides:

- Pre-configured root and nixos user passwords
- SSH key authentication
- Enabled SSH daemon by default
- Network configuration (DHCP/static)
- Required deployment tools pre-installed
- Wolkenschloss-specific optimizations

## Quick Start

```bash
# Build with default configuration x86_64
./installer/build-iso.sh
```

```bash
# Build for ARM64
./build-iso.sh aarch64-linux

# Build with SSH keys
./build-iso.sh x86_64-linux -k "ssh-rsa AAAA...,ssh-ed25519 AAAA..."

# Build with custom password hash
./build-iso.sh x86_64-linux -p '$6$rounds=4096$salt$hash'

# Clean build cache first
./build-iso.sh --clean aarch64-linux
```

### Direct Nix Commands

```bash
# Build for x86_64
nix build '.#packages.x86_64-linux.installer'

# Build for ARM64
nix build '.#packages.aarch64-linux.installer'

# Build with environment variables
SSH_KEYS="ssh-rsa AAAA..." NIXOS_PASSWORD_HASH='$6$...$hash' \
  nix build '.#packages.x86_64-linux.installer'
```
