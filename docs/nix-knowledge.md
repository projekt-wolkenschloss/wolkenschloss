# Nix related knowledge store

## Installing Nix

Because I'm new to the Nix world, I still am not certain how to use it properly.
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
