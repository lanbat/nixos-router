{ config, lib, pkgs, ... }:

let
  vars = import ./variables.nix;

  inherit (vars) vlans subnetPrefix;
  getVlanIp = id: "${subnetPrefix}${toString id}.1";
in
{
  networking.useDHCP = false;

  networking.interfaces.${vars.physicalNic} = { };

  networking.vlans = lib.mapAttrs (_name: cfg: {
    inherit (cfg) id;
    interface = vars.physicalNic;
  }) vlans;

  networking.bridges = lib.mapAttrs (name: _cfg: {
    interfaces = [ name ];
  }) vlans;

  networking.interfaces = lib.mkMerge (
    lib.mapAttrsToList (name: cfg: {
      "${name}br".ipv4.addresses = [{
        address = getVlanIp cfg.id;
        prefixLength = 24;
      }];
    }) vlans
  );
}

