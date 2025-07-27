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
