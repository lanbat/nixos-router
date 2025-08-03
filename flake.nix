{
  description = "NixOS Multi-VLAN Router Test Suite";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    nixosTests = {
      nixos-multivlan = import ./tests/nixos-multivlan-full.nix {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        lib = nixpkgs.lib;
        callPackage = nixpkgs.legacyPackages.x86_64-linux.callPackage;
        makeTest = import ./tests/make-test.nix;
      };
    };
  };
}

