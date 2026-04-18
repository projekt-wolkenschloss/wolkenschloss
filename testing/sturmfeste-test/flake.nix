{
  description = "A test and example flake for the Sturmfeste component";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";
    wolkenschloss = {
      url = "path:./../..";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
      inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: {
    nixosConfigurations = {
      test = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inputs = inputs // inputs.wolkenschloss.inputs;
        };
        modules = [
          ./configuration.nix
        ];
      };
    };
  };
}
