# Testing

The testing directories aim is to provide ways to test the Wolkenschloss.

## Preparing a test environment

Prerequisites:

1. A Proxmox host
2. SSH Keys and sudo access to the Proxmos host
3. An installer iso from the `installer` directory

First, setup the environment variables with `cp .env.template .env` and fill in the required variables.
To create a new password hash, use `sudo apt install whois`, then `mkpasswd <your-password>`.

Then, you need to create a test VM:

```bash
./vm-manager.sh create <scenario-name> <iso-file>
```

start it with `./vm-manager.sh start <vmid>` and test connectivity with `./vm-manager.sh ssh <vmid>`.

Now the vm is ready for remote provisioning!

To provision, run

```bash
NIX_CONFIG="../#<configuration name>"
TARGET_HOST_IP="<ip address>"
SSH_KEY_FILE="/path/to/ssh/key"
nix run github:nix-community/nixos-anywhere -- -i "$SSH_KEY_FILE" --generate-hardware-config nixos-generate-config ./hardware-configuration.nix --flake "$NIX_CONFIG" --target-host nixos@"$TARGET_HOST_IP"
```
