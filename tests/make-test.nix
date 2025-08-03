{ pkgs, lib, callPackage }:

{ name, nodes, testScript }:

pkgs.nixosTest {
  inherit name nodes;
  testScript = ''
    from test_driver import TestDriver
    from contextlib import contextmanager

    class CustomDriver(TestDriver):
      def run(self):
${testScript}
    CustomDriver().run()
  '';
}

