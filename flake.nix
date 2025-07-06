{
  description = "The Wolkenschloss flake";

  inputs = {
    # NixOS official packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    facter-modules.url = "github:numtide/nixos-facter-modules";
    #    wolkenschloss.url = "github:projekt-wolkenschloss/wolkenschloss/feature/a-simple-backup-server";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      nixos-wsl,
      nixos-hardware,
      home-manager,
      disko,
      facter-modules,
      ...
    }:
    {
      formatter = {
        x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
        aarch64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
        i686-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
        x86_64-darwin = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
      };
      nixosConfigurations = {
        wolkenschloss-development-wsl = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          system = "x86_64-linux";
          modules = (import ./machines/wolkenschloss-development-wsl.nix) inputs;
        };

        nixos-testing-1 = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          system = "x86_64-linux";
          modules = [
            nixos-wsl.nixosModules.default
            {
              system.stateVersion = "24.11";
              wsl.enable = true;
            }
            ./machines/nixos-testing-1.nix
          ];
        };

        backup-server = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          system = "x86_64-linux";
          modules = (import ./machines/backup-server.nix) inputs;
        };
      };
    };
}
