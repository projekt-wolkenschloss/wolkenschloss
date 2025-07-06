{ self, nixpkgs, disko, nixos-hardware, facter-modules, ... }:
[
  # Importing the nixos-hardware module for Raspberry Pi 3B
  nixos-hardware.nixosModules.raspberry-pi-3
  # Importing the Raspberry Pi 3B specific configuration
  ../devices/raspi-3B.nix
  {
    system.stateVersion = "25.05";
    networking.hostName = "sturmfeste";

    # Explicitly setting nix path for nixos-anywhere deployment
    # See https://github.com/nix-community/nixos-anywhere/blob/main/docs/howtos/nix-path.md
    nix.nixPath = [ "nixpkgs=${nixpkgs}" ];
    environment.systemPackages = with pkgs; [
      nano
    ];

    services.openssh = {
      enable = true;
      openFirewall = true;
    };
  }

  facter-modules.nixosModules.facter
#  {
#    config.facter.reportPath = ./facter.json;
#  }

  disko.nixosModules.disko
  {
    disko.devices.disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-diskseq/1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "128M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # Override existing partition
                # Subvolumes must set a mountpoint in order to be mounted,
                # unless their parent is mounted
                subvolumes = {
                  # Subvolume name is different from mountpoint
                  "/rootfs" = {
                    mountpoint = "/";
                  };
                  # Subvolume name is the same as the mountpoint
                  "/home" = {
                    mountOptions = [ "compress=zstd" ];
                    mountpoint = "/home";
                  };
                  # Sub(sub)volume doesn't need a mountpoint as its parent is mounted
                  "/home/user" = { };
                  # Parent is not mounted so the mountpoint must be set
                  "/nix" = {
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                    mountpoint = "/nix";
                  };
                  # This subvolume will be created but not mounted
                  "/test" = { };
                  # Subvolume for the swapfile
                  "/swap" = {
                    mountpoint = "/.swapvol";
                    swap = {
                      swapfile.size = "20M";
                      swapfile2.size = "20M";
                      swapfile2.path = "rel-path";
                    };
                  };
                };

                mountpoint = "/partition-root";
                swap = {
                  swapfile = {
                    size = "20M";
                  };
                  swapfile1 = {
                    size = "20M";
                  };
                };
              };
            };
          };
        };
      };
    };
  }
]
