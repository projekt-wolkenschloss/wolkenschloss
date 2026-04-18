# Sturmfeste Test Flake

This is a test flake that serves as an example and development playground for the Sturmfeste system.

`nix build/run .#nixosConfigurations.test.config.system.build.vm`

## Getting Started

First, setup a flake with nixpkgs as a dependency:

```nix
{
  description = "A test and example flake for the Sturmfeste component";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";
  };

  outputs = inputs: {
    nixosConfigurations = {
      test = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inputs = inputs;
        };
        modules = [
          ./configuration.nix
        ];
      };
    };
  };
}
```

Then, create a `configuration.nix` and `hardware-configuration.nix` and add the necessary configuration for a basic NixOS system.
Afterwards, add the Projekt Wolkenschloss Sturmfeste module to the flake:

```nix
{
  inputs = {
    #...
    wolkenschloss = {
      url = "git+https://codeberg.org/projekt-wolkenschloss/wolkenschloss?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
      inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: {
    nixosConfigurations = {
      test = inputs.nixpkgs.lib.nixosSystem {
        specialArgs = {
          inputs = inputs // inputs.wolkenschloss.inputs;
        };
        # ...
      };
    };
  };
}
```

Now, the Sturmfeste module is available.
To use it properly, you need to enable and configure it in your `configuration.nix`:

```nix
  wks.sturmfeste = {
    enable = true;
    # To get ssh access
    adminPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFRTzZFhr6KACic0O5G1n+erg07weo+YFrC5UKCuB/py username@hostname";
    # SOPS secrets used by the host and Wolkenschloss modules.
    secretsFile = ./secrets.json;
  };

  # Configures partitioning for the root device when using Disko with nixos-anywhere for declarative partitioning.
  wolkenschloss.modules.disko.simpleExt4 = {
    enable = true;
    rootDevice = "/dev/nvme0n1";
  };
```

Make sure that you create a secrets file that contains the secrets used by the system. See [Secret Operations](./../docs/secret-operations.md).
