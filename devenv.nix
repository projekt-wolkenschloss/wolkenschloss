{ pkgs, ... }:

{
  # See full reference at https://devenv.sh/reference/options/

  # https://devenv.sh/basics/
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  packages = with pkgs; [
    qemu
    nixos-anywhere
    zstd
    wget
    # Nix language server for IDE integration
    nixd
    sops
    age
    ssh-to-age
  ];

  # https://devenv.sh/scripts/
  scripts.hello.exec = ''
    echo hello from $GREET
  '';

  # https://devenv.sh/basics/
  enterShell = ''
    hello
    git --version
  '';

  languages.python = {
    enable = true;
    version = "3.14";
    directory = "./tests";

    venv.enable = true;

    uv = {
      enable = true;
      sync.enable = true;
    };
  };

  tasks = {
    "all:update-devenv" = {
      exec = "devenv update";
    };

    "all:update-flake" = {
      exec = "nix flake update";
    };
  };
}
