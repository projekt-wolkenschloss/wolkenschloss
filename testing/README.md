# Testing

The testing directory's aim is to provide ways to test the Wolkenschloss.

## Preparing a test environment

### Proxmox as VM Host

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


### Local QEMU VMs

Instead you can use locally running qemu vms to test Wolkenschloss.

```shell
# Activate the dev environment
devenv shell

# Start the VM
SCENARIO="<scenario-name>"
cd scenarios/qemu-"$SCENARIO" && quickemu --vm quickemu.conf

# Connect to the VM. When the ISO was created with a preconfigured SSH, use that.
ssh -o "StrictHostKeyChecking=no" -p 22220 -i ~/.ssh/<KEY> nixos@localhost
```

## Provisioning

Now with a vm running the Wolkenschloss NixOS installer, we can continue with remote provisioning!

TIP: Make sure you're in the devenv shell!

To provision, run

```bash
NIX_CONFIG="../#<configuration name>"
TARGET_HOST_IP="<ip address>"
SSH_KEY_FILE="/path/to/ssh/key"
nixos-anywhere -i "$SSH_KEY_FILE" --generate-hardware-config nixos-generate-config ./hardware-configuration.nix --flake "$NIX_CONFIG" --target-host nixos@"$TARGET_HOST_IP"
```

Using defaults, this would look like

```bash
NIX_CONFIG="../#wlknslos-single-storage-device"
TARGET_HOST_IP="localhost"
SSH_KEY_FILE="/home/geothain/.ssh/id_ed25519_wolkenschloss_test_vms"

nixos-anywhere -i "$SSH_KEY_FILE" -p 22220 --generate-hardware-config nixos-generate-config ./hardware-configuration.nix --flake "$NIX_CONFIG" --target-host nixos@"$TARGET_HOST_IP"
```
