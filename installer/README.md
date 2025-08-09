# Wolkenschloss Custom Installer

NixOS has no default passwords for a sudo enabled account, so you need physical access to set the initial passwords.
This directory contains the configurations and tools for creating custom NixOS installer ISOs with pre-configured authentication for automated and remote deployment and testing.

It provides pre-configured:

- nixos user with password
- SSH key authentication
- Enabled SSH daemon by default
- DHCP network config
- mDNS for local network device discovery

## Quick Start

```bash
./build-iso.sh
```

For more, see `./build-iso.sh --help`.

For easy iteration, we recommend first creating an ssh key pair:
`ssh-keygen -t ed25519 -C "wolkenschloss-developer-key-for-test-vms" -f ~/.ssh/id_ed25519_wolkenschloss_test_vms`

then using the `-K` option to specify the public key file: `./build-iso.sh -K ~/.ssh/id_ed25519_wolkenschloss_test_vms.pub`.
