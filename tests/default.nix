{ pkgs ? import <nixpkgs> {} }:

let
  callTest = import ./make-test.nix { inherit (pkgs) callPackage; };
in {
  nixos-multivlan = callTest (import ./nixos-multivlan-full.nix);
}

