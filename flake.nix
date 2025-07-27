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
    treefmt-nix.url = "github:numtide/treefmt-nix";
    #    facter-modules.url = "github:numtide/nixos-facter-modules";
    #    wolkenschloss.url = "github:projekt-wolkenschloss/wolkenschloss/feature/a-simple-backup-server";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      treefmt-nix,
      #      facter-modules,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Iterate over each system and pass nixpkgs.legacyPackages to the passed function
      eachSystem =
        fun: nixpkgs.lib.genAttrs supportedSystems (system: fun nixpkgs.legacyPackages.${system});

      # Eval the treefmt modules from ./treefmt.nix
      treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
    in
    {
      # for `nix fmt`
      formatter = eachSystem (pkgs: treefmtEval.${pkgs.system}.config.build.wrapper);
      # for `nix flake check`
      checks = eachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.system}.config.build.check self;
      });

      nixosConfigurations = {
        wolkenschloss-development-wsl = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          system = "x86_64-linux";
          modules = (import ./machines/wolkenschloss-development-wsl.nix) inputs;
        };

        nixos-testing-1 = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          system = "x86_64-linux";
          modules = (import ./machines/nixos-testing) inputs;
        };

        backup-server = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          system = "x86_64-linux";
          modules = (import ./machines/backup-server.nix) inputs;
        };
      };
    };
}
