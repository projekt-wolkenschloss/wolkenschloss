# Testing

The testing directory's aim is to provide ways to test the Wolkenschloss.

## Preparing a test environment

First, setup the environment variables with `cp .env.template .env` and fill in the required variables.

### Proxmox as VM Host

Prerequisites:

1. A Proxmox host
2. SSH Keys and sudo access to the Proxmos host
3. An installer iso from the `installer` directory

To create a new password hash, use `sudo apt install whois`, then `mkpasswd <your-password>`.

Then, you need to create a test VM:

```bash
./proxmox-vm-manager.sh create <scenario-name> <iso-file>
```

start it with `./proxmox-vm-manager.sh start <vmid>` and test connectivity with `./proxmox-vm-manager.sh ssh <vmid>`.

### Local QEMU VMs

Instead you can use locally running qemu vms to test Wolkenschloss.

```shell
# Activate the dev environment, if not done automatically
devenv shell


SCENARIO="<scenario-name>"
cd scenarios/qemu-"$SCENARIO"

# Create a compressed disk image
rm sata0.qcow
qemu-img create -f qcow sata0.qcow 128G

# Start the VM
quickemu --vm quickemu.conf --keyboard_layout DE_de --extra_args "-drive file=sata0.qcow,id=sata-drive,if=none \
    -device ahci,id=ahci \
    -device ide-hd,drive=sata-drive,bus=ahci.0"

# Connect to the VM. When the ISO was created with preconfigured SSH, use that.
ssh -o "StrictHostKeyChecking=no" -p 22220 -i ~/.ssh/<KEY> nixos@localhost
```

## Provisioning

Now with a vm running the Wolkenschloss NixOS installer, we can continue with remote provisioning!

TIP: Make sure you're in the devenv shell!

To provision, run

```bash
nixos-anywhere -i "$SSH_KEY_FILE" -p 22220 --post-kexec-ssh-port 22220 --generate-hardware-config nixos-generate-config ./hardware-configuration.nix --flake "$NIX_CONFIG" --target-host nixos@"$TARGET_HOST_IP"
```
