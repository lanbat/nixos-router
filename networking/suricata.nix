{ config, pkgs, lib, ... }:

let
  inherit (import ./variables.nix) suricataVLANs;
in
{
  services.suricata = {
    enable = true;
    interfaces = builtins.map (name: "${name}br") suricataVLANs;
    yamlConfig = {
      af-packet = builtins.map (name: {
        interface = "${name}br";
        cluster-id = 99;
        cluster-type = "cluster_flow";
        defrag = "yes";
      }) suricataVLANs;

      outputs = {
        eve-log = {
          enabled = true;
          filetype = "regular";
          filename = "/var/log/suricata/eve.json";
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ]; # allow SSH for rule testing
}

