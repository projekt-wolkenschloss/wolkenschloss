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
        # Base system configuration
        system.stateVersion = "25.05";

        hardware = {
          enableRedistributableFirmware = true;
        };

        boot = {
          supportedFilesystems = [ "zfs" ];
          kernelParams = [
            "zfs_force=1"
          ];
        };

        # Static IP configuration for small disk scenario
        networking = {
          hostName = "nixos-testing-small";
          useDHCP = false;  # Disable DHCP for static IP
          # Required by zfs
          hostId = "4a967f49";
          
          # Configure static IP
          interfaces = {
            eth0 = {
              useDHCP = false;
              ipv4.addresses = [
                {
                  address = "192.168.1.100";
                  prefixLength = 24;
                }
              ];
              ipv6.addresses = [ ];
            };
          };
          
          # Set default gateway
          defaultGateway = "192.168.1.1";
          nameservers = [ "8.8.8.8" "8.8.4.4" ];
        };

        # Disable Docker for small disk scenario to save space
        virtualisation.docker.enable = false;

        services.openssh = {
          enable = true;
          openFirewall = true;
        };

        # Enable ZFS support and configure it
        services.zfs = {
          # Enables ZFS trimming, informing the storage devices about unused blocks that can be reclaimed
          trim.enable = true;
          trim.interval = "weekly";
          # Enables automatic scrubbing of ZFS pools.
          # Read more here: https://blogs.oracle.com/oracle-systems/post/disk-scrub-why-and-when
          autoScrub.enable = true;
          autoScrub.interval = "monthly";
        };
      }
    ];
  };
}
