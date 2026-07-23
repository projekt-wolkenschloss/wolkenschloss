{
  description = "The Wolkenschloss flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix.url = "github:numtide/treefmt-nix";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
      treefmt-nix,
      sops-nix,
      ...
    }@inputs:
    let
      inherit (inputs.nixpkgs) lib;
      supportedSystems = [
        "x86_64-linux"
      ];

      # Iterate over each system and pass nixpkgs.legacyPackages to the passed function
      eachSystem =
        fun: nixpkgs.lib.genAttrs supportedSystems (system: fun nixpkgs.legacyPackages.${system});

      # Eval the treefmt modules from ./treefmt.nix
      treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);

      forEachSupportedSystem =
        fun:
        lib.genAttrs supportedSystems (
          system:
          fun {
            inherit system;
            pkgs = import inputs.nixpkgs { inherit system; };
          }
        );
    in
    {
      # for `nix fmt`
      formatter = eachSystem (pkgs: treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper);

      # for `nix flake check`
      checks = eachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.check self;
      });

      nixosModules = {
        sturmfeste = { ... }: {
          imports = [
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            ./modules/sturmfeste
          ];
        };
      };

      packages = eachSystem (pkgs: {
        test-minimal = pkgs.testers.runNixOSTest ./src/tests/minimal.nix;
        test-sturmfeste = pkgs.testers.runNixOSTest (
          import ./src/tests/sturmfeste.nix {
            inherit inputs pkgs;
            inherit (inputs.nixpkgs) lib;
          }
        );
      });

      # Default based off of https://github.com/the-nix-way/dev-templates
      devShells = forEachSupportedSystem (
        { pkgs, system }:
        let
          /*
            Change this value ({major}.{min}) to update the Python virtual-environment version. When you do this, make sure
            to delete the `.venv` directory to have the hook rebuild it for the new version, since it won't overwrite an
            existing one. After this, reload the development shell to rebuild it. You'll see a warning asking you to
            do this when version mismatches are present. For safety, removal should be a manual step, even if trivial.
          */
          version = "3.13";
          concatMajorMinor =
            v:
            lib.pipe v [
              lib.versions.splitVersion
              (lib.sublist 0 2)
              lib.concatStrings
            ];

          python = pkgs."python${concatMajorMinor version}";
        in
        {
          default = pkgs.mkShellNoCC {
            venvDir = ".venv";

            postShellHook = ''
              venvVersionWarn() {
              	local venvVersion
              	venvVersion="$("$venvDir/bin/python" -c 'import platform; print(platform.python_version())')"

              	[[ "$venvVersion" == "${python.version}" ]] && return

              	cat <<EOF
              Warning: Python version mismatch: [$venvVersion (venv)] != [${python.version}]
                       Delete '$venvDir' and reload to rebuild for version ${python.version}
              EOF
              }

              venvVersionWarn
            '';

            packages =
              with pkgs;
              [
                qemu
                nixd
                sops
                age
                ssh-to-age
              ]
              ++ (with python.pkgs; [
                venvShellHook
                pip
                pkgs.nixos-test-driver
                ty
                numpy
              ])
              ++ [ self.formatter.${system} ];

            PYTHONPATH = "./src/tests";
          };
        }
      );
    };
}
