# Deployment 

The aim of Wolkenschloss first-time deployment is to allow an easy and unattended installation
onto a VM or physical hardware.

## Deployment on Bare Metal without Operating System

The user should have two options:

A. Creating a bootable drive with a pre-configured Wolkenschloss image via another computer

B. Creating a bootable drive with a standard NixOS image and the installing Wolkenschloss

### Option A: Booting and installing Wolkenschloss

#### How it works

**We do not support this yet. This is the basic idea yet to be implemented**

We create the Wolkenschloss config as a set of flakes and configurations.
We use [Disko](https://github.com/nix-community/disko) to declaratively partition the drives of the actual hardware.
We use [nixos-facter](https://github.com/nix-community/nixos-facter?tab=readme-ov-file) to
detect the hardware during installation.

### Option B: Booting standard NixOS and installing Wolkenschloss

We use [Nixos-anywhere](https://github.com/nix-community/nixos-anywhere) for deployment

Prerequisites:

- You need a connected display
- You need connected input devices (keyboard, mouse)

1. Flash a drive with standard NixOS 24.11
2. Boot from the drive
3. Change the password with `passwd`
4. Get the IP address with `ip addr`
5. Test if you can connect and your password works: `ssh -v nixos@<ip-address>`
6. Deploy wolkenschloss with
`nix run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-facter ./facter.json --flake '.#myconfig' --target-host nixos@<ip-address>`


## Deployment on Bare Metal with Operating System

We do not support this yet.

## Deployment on a VM

We do not support this yet.
