{
  description = "Wolkenschloss Custom Installer ISOs";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko/v1.11.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-generators,
      disko,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
      ];
      installerName = "wolkenschloss-installer";
      vmHostName =
        if (builtins.getEnv "VM_HOST_NAME") != "" then
          builtins.getEnv "VM_HOST_NAME"
        else
          "wolkenschloss-nixos-test-vm";
        
      sshKey =
        if (builtins.getEnv "VM_SSH_KEY") != "" then
          assert (builtins.stringLength (builtins.getEnv "VM_SSH_KEY") > 0);
          builtins.getEnv "VM_SSH_KEY"
        else 
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPfdblJ4KYOY8aLSnPigAhinhAnUyXxMLsTbGmmg15YC wolkenschloss-developer-key-for-test-vms";
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
            nixpkgs = nixpkgs.legacyPackages.${system};
            inherit installerName sshKey nixosPasswordHash;
            hostName = vmHostName;
            keyboardLayoutShortCode = "de";
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
          ./modules/zfs.nix
          disko.nixosModules.disko
        ];

        default = self.packages.${system}.iso;
      });
    };
}
