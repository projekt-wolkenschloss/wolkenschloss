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
      vmHostName = if (builtins.getEnv "VM_HOST_NAME") != "" then
        builtins.getEnv "VM_HOST_NAME"
      else
        "wolkenschloss-nixos-test-vm";

      sshKeys = nixpkgs.lib.splitString "," (builtins.getEnv "VM_SSH_KEYS");
      nixosPasswordHash =
        if (builtins.getEnv "VM_NIXOS_PASSWORD_HASH") != "" then
          builtins.getEnv "VM_NIXOS_PASSWORD_HASH"
        else
          "$y$j9T$/sYOC0Od9Yf1OARxHgUV2.$JtFLVQ.CoUkw4mqYmLY1TFgq2C0IVvUBO278Fh2cY.3"; # test

      # Creates installer configs
      generateIso =
        system: modules:
        nixos-generators.nixosGenerate {
          inherit system;
          format = "iso";
          modules = modules;
          specialArgs = {
            inherit (self.inputs) nixpkgs;
            inherit installerName sshKeys nixosPasswordHash;
            hostName = vmHostName;
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
