{
  name = "A minimal test using the NixOS test framework";

  globalTimeout = 600;
  qemu.forceAccel = true;

  nodes = {
    hello_vm =
      {
        pkgs,
        ...
      }:
      {
        environment.systemPackages = [ pkgs.hello ];
      };
  };

  testScript = ''
    start_all()
    output = hello_vm.succeed("hello")

    t.assertIn("Hello, world", output, "Wrong output")
  '';
}
