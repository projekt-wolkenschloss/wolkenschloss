# Integration with Main Flake
# Add this to your main flake.nix to include the custom installer ISOs

{
  # ... existing inputs and outputs ...

  # Add installer ISO outputs
  packages.x86_64-linux = {
    # ... existing packages ...
    
    # Basic installer ISO
    installer-iso-base = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./installer/base-installer.nix ];
    }.config.system.build.isoImage;
    
    # Custom installer with authentication
    installer-iso-custom = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./installer/custom-installer.nix ];
    }.config.system.build.isoImage;
    
    # Secure installer
    installer-iso-secure = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./installer/secure-installer.nix ];
    }.config.system.build.isoImage;
  };

  # Alternative using nixos-generators (if available as input)
  # packages.x86_64-linux = {
  #   installer-iso-custom = nixos-generators.nixosGenerate {
  #     system = "x86_64-linux";
  #     format = "iso";
  #     modules = [ ./installer/custom-installer.nix ];
  #   };
  # };
}

# Usage examples:
# nix build .#installer-iso-custom
# nix build .#installer-iso-secure
