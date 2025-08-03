{ config, pkgs, lib, ... }:

let
  inherit (import ../networking/variables.nix) vlans;

  containerVeths = [
    {
      name = "homeassistant";
      vlan = vlans.iot;
      ip = "192.168.50.3/24";
    }
    {
      name = "shinobi";
      vlan = vlans.iot;
      ip = "192.168.50.4/24";
    }
    {
      name = "deluge";
      vlan = vlans.media;
      ip = "192.168.60.4/24";
    }
    {
      name = "bitmagnet";
      vlan = vlans.media;
      ip = "192.168.60.5/24";
    }
    {
      name = "keycloak";
      vlan = vlans.services;
      ip = "192.168.70.5/24";
    }
    {
      name = "authgate";
      vlan = vlans.services;
      ip = "192.168.70.6/24";
    }
    {
      name = "vaultwarden";
      vlan = vlans.services;
      ip = "192.168.70.7/24";
    }
  ];
in
{
  systemd.network.enable = true;

  systemd.network.networks = builtins.listToAttrs (
    builtins.map (entry: {
      name = "veth-${entry.name}";
      value = {
        matchConfig.Name = "veth-${entry.name}";
        networkConfig = {
          Bridge = "br-${entry.vlan.name}";
        };
      };
    }) containerVeths
  );

  systemd.network.links = builtins.listToAttrs (
    builtins.map (entry: {
      name = "hostlink-${entry.name}";
      value = {
        matchConfig.MACAddress = null;
        linkConfig = {
          Name = "veth-${entry.name}";
        };
      };
    }) containerVeths
  );

  systemd.network.netdevs = builtins.listToAttrs (
    builtins.map (entry: {
      name = "veth-${entry.name}";
      value = {
        netdevConfig = {
          Kind = "veth";
          Name = "veth-${entry.name}";
        };
        peerConfig.Name = "eth0";
      };
    }) containerVeths
  );
}

