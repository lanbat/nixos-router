{ config, lib, ... }:

let
  vars = import ./variables.nix;
in
{
  networking.interfaces = lib.mkMerge (
    lib.mapAttrsToList (_: vlan: {
      "${vlan.name}br".ipv4.addresses = [{
        address = "${vars.subnetPrefix}${toString vlan.id}.1";
        prefixLength = 24;
      }];
    }) vars.vlans
  );
}

