{
  description = "Wolkenschloss Custom Installer ISOs";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators, ... }: 
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    installerName = "wolkenschloss-installer";
        
    # Helper function to create installer configs
    makeInstaller = modules: nixos-generators.nixosGenerate {
      inherit system;
      format = "iso";
      modules = modules;
      specialArgs = {
        inherit (self.inputs) nixpkgs;
        inherit installerName;
      };
    };
    
  in {
    # ISO packages
    packages.${system} = {
      # Basic installer with minimal auth
      installer = makeInstaller [ ./modules/base.nix ./modules/auth.nix ];
    };
    
    # NixOS configurations for integration
    nixosConfigurations = {
      installer = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ 
          ./modules/base.nix 
          ./modules/auth.nix 
         ];
      };
    };
  };
}
