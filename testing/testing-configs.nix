# Testing Configuration Override
# This file can be used to create variations of your main nixos-testing configuration
# for different testing scenarios

{ inputs, ... }:
{
  # Test configuration for RAID mirror scenario
  nixos-testing-mirror = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    system = "x86_64-linux";
    modules = [
      inputs.disko.nixosModules.disko
      ./scenarios/raid-mirror-disko.nix
      {
        # Use the base configuration but with mirror-specific overrides
        imports = [
          ../machines/nixos-testing/default.nix
        ];
        
        # Override hostname for mirror testing
        networking.hostName = "nixos-testing-mirror";
        
        # Different host ID for ZFS
        networking.hostId = "4a967f47";
      }
    ];
  };

  # Test configuration for RAIDZ scenario  
  nixos-testing-raidz = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    system = "x86_64-linux";
    modules = [
      inputs.disko.nixosModules.disko
      ./scenarios/raidz-disko.nix
      {
        imports = [
          ../machines/nixos-testing/default.nix
        ];
        
        networking.hostName = "nixos-testing-raidz";
        networking.hostId = "4a967f48";
      }
    ];
  };

  # Test configuration for small disk scenario
  nixos-testing-small = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    system = "x86_64-linux";
    modules = [
      inputs.disko.nixosModules.disko
      ./scenarios/small-disk-disko.nix
      {
        imports = [
          ../machines/nixos-testing/default.nix
        ];
        
        networking.hostName = "nixos-testing-small";
        networking.hostId = "4a967f49";
        
        # Disable Docker for small disk scenario
        virtualisation.docker.enable = false;
      }
    ];
  };
}
