{
  self,
  inputs,
  pkgs,
  ...
}:
{

  mkSystem =
    hostConfig: extraInputs: arch:
    pkgs.lib.nixosSystem {
      system = "${arch}";
      specialArgs = {
        inherit inputs;
      }
      // extraInputs;
      modules = [
        hostConfig
      ];
    };
  mkX86System = hostConfig: extraInputs: self.mkSystem hostConfig extraInputs "x86_64-linux";
  mkAarchSystem = hostConfig: extraInputs: self.mkSystem hostConfig extraInputs "aarch64-linux";
}
