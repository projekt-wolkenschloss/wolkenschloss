{
  description = "The Wolkenschloss flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix.url = "github:numtide/treefmt-nix";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
      treefmt-nix,
      sops-nix,
      ...
    }@inputs:
    let
      supportedSystems = [
        "x86_64-linux"
      ];

      # Iterate over each system and pass nixpkgs.legacyPackages to the passed function
      eachSystem =
        fun: nixpkgs.lib.genAttrs supportedSystems (system: fun nixpkgs.legacyPackages.${system});

      # Eval the treefmt modules from ./treefmt.nix
      treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
    in
    {
      # for `nix fmt`
      formatter = eachSystem (pkgs: treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper);

      # for `nix flake check`
      checks = eachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.check self;
      });

      nixosModules = {
        sturmfeste = { ... }: {
          imports = [
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            ./modules/sturmfeste
          ];
        };
      };

      packages =
        let
          sturmfesteTest = import ./testing/sturmfeste.nix {
            inherit inputs;
            pkgs = nixpkgs;
          };
        in
        eachSystem (pkgs: {
          test-minimal = pkgs.testers.runNixOSTest ./testing/minimal.nix;
          test-sturmfeste = pkgs.testers.runNixOSTest sturmfesteTest;
        });
    };
}
