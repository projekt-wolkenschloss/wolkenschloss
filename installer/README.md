# Wolkenschloss Custom Installer

This directory contains the configurations and tools for creating custom NixOS installer ISOs with pre-configured authentication for Wolkenschloss deployment and testing.

## Overview

The custom installer solves the fundamental problem of needing physical access to set passwords for automated deployment. It provides:

- Pre-configured root and nixos user passwords
- SSH key authentication
- Enabled SSH daemon by default
- Network configuration (DHCP/static)

## Quick Start

```bash
./installer/build-iso.sh
```

For more, see `./build-iso.sh --help`.

For easy iteration, we recommend first creating an ssh key pair:
`ssh-keygen -t ed25519 -C "wolkenschloss-developer-key-for-test-vms" -f ~/.ssh/id_ed25519_wolkenschloss_test_vms`

then using the `-K` option to specify the public key file: `./build-iso.sh -K ~/.ssh/id_ed25519_wolkenschloss_test_vms.pub`.
