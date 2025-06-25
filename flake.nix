{
    description = "The Wolkenschloss flake";

    inputs = {
        # NixOS official packages
        nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
        nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
        home-manager = {
            url = "github:nix-community/home-manager/release-25.05";
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs = {
        self,
        nixpkgs,
        nixpkgs-unstable,
        home-manager,
        ...
    }@inputs: {
        nixosConfigurations = {
            backup-server = nixpkgs.lib.nixosSystem {
                specialArgs = { inherit inputs; };
                modules = [
                ];
            };
        };
    };
}
