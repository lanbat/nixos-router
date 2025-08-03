{ config, lib, pkgs, ... }:

let
  inherit (import ./variables.nix) vlans physicalNic;
in
{
  networking = {
    useDHCP = false;
    interfaces = lib.mkMerge (lib.mapAttrsToList (name: vlan:
      {
        "vlan${toString vlan.id}" = {
          virtual = true;
          vlan = {
            id = vlan.id;
            interface = physicalNic;
          };
        };
      }
    ) vlans);

    bridges = {
      mgmtbr = { interfaces = [ "vlan10" ]; };
      mainbr = { interfaces = [ "vlan20" ]; };
      iotbr  = { interfaces = [ "vlan30" ]; };
      guestbr = { interfaces = [ "vlan40" ]; };
      mediabr = { interfaces = [ "vlan50" ]; };
      isolbr = { interfaces = [ "vlan60" ]; };
      svcbr  = { interfaces = [ "vlan70" ]; };
    };

    interfaces.mgmtbr.ipv4.addresses = [{ address = "192.168.10.1"; prefixLength = 24; }];
    interfaces.mainbr.ipv4.addresses = [{ address = "192.168.20.1"; prefixLength = 24; }];
    interfaces.iotbr.ipv4.addresses  = [{ address = "192.168.30.1"; prefixLength = 24; }];
    interfaces.guestbr.ipv4.addresses = [{ address = "192.168.40.1"; prefixLength = 24; }];
    interfaces.mediabr.ipv4.addresses = [{ address = "192.168.50.1"; prefixLength = 24; }];
    interfaces.isolbr.ipv4.addresses  = [{ address = "192.168.60.1"; prefixLength = 24; }];
    interfaces.svcbr.ipv4.addresses   = [{ address = "192.168.70.1"; prefixLength = 24; }];

    defaultGateway = "192.168.20.1"; # Example
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
  };
}

