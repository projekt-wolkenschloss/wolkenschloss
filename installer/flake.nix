{
  description = "Wolkenschloss Custom Installer ISOs";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-generators,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
      ];
      installerName = "wolkenschloss-installer";

      # Creates installer configs
      generateIso =
        system: modules:
        nixos-generators.nixosGenerate {
          inherit system;
          format = "iso";
          modules = modules;
          specialArgs = {
            inherit (self.inputs) nixpkgs;
            inherit installerName;
          };
        };

      forEachSystem = fun: nixpkgs.lib.genAttrs supportedSystems (system: fun system);
    in
    {
      # Create ISOs for each supported system
      packages = forEachSystem (system: {
        iso = generateIso system [
          ./modules/base.nix
          ./modules/auth.nix
        ];
        
        default = self.packages.${system}.installer;
      });
    };
}
