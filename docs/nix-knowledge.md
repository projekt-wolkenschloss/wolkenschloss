# Nix related knowledge store

Because I'm new to the Nix world, I still am not certain how to use everything properly.
Here I document stuff I want to remember for now. Sometime in the future, this
will be removed or reworked to a contribution guide.

## Installing Nix in WSL

Install like here: <https://nix-community.github.io/NixOS-WSL/install.html>

`wsl --install --name <name> --from-file nixos.wsl`

then `sudo nix-channel --update && sudo nixos-rebuild switch`

## Installing Nix on Ubuntu

In this section, I will document a temporary setup, hopefully soon to be replaced by a 
nix pure setup :)

In a Ubuntu WSL, install nix multiuser:

```bash
$ bash <(curl -L https://nixos.org/nix/install) --daemon
```

Then, update `/etc/nix/nix.conf` to include the following lines:

```conf
keep-outputs = true
build-users-group = nixbld
extra-experimental-features = flakes nix-command
```

## Useful commands

To detect dead code locally: `nix run github:astro/deadnix`

## Nix Knowledge

Use https://github.com/nix-community/awesome-nix
