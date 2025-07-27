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
        "aarch64-linux"
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
      # Create ISOs
      packages = forEachSystem (_system: {
        # Basic installer with minimal auth
        installer = generateIso _system [
          ./modules/base.nix
          ./modules/auth.nix
        ];
        
        default = self.packages.${_system}.installer;
      });
      # Create ISOs
      # packages."x86_64-linux" = {
      #   installer = generateIso "x86_64-linux" [
      #     ./modules/base.nix
      #     ./modules/auth.nix
      #   ];
      # };

      # NixOS configurations for integration
      nixosConfigurations = {
        installer = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./modules/base.nix
            ./modules/auth.nix
          ];
        };
      };
    };
}
