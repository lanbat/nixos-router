# Declarative nftables firewall configuration
{ config, pkgs, lib, ... }:

let
  subnetPrefix = "192.168";
in {
  networking.nftables.enable = true;
  networking.firewall.enable = false;

  networking.nftables.ruleset = ''
    table inet filter {
      chain input {
        type filter hook input priority 0;
        policy drop;

        iif lo accept
        ct state established,related accept

        # Allow VLAN-specific input
        ip saddr ${subnetPrefix}.10.0/24 tcp dport { 22, 51820 } accept
        ip saddr ${subnetPrefix}.70.0/24 udp dport { 53, 67, 123 } accept
        ip saddr ${subnetPrefix}.30.0/24 ip daddr ${subnetPrefix}.40.0/24 accept
        ip saddr ${subnetPrefix}.30.0/24 ip daddr ${subnetPrefix}.10.0/24 accept
        ip saddr ${subnetPrefix}.60.0/24 ip dport 9050 accept  # Tor
        ip saddr ${subnetPrefix}.60.0/24 ip dport 4444 accept  # I2P
        ip saddr ${subnetPrefix}.50.0/24 ip daddr != ${subnetPrefix}.0.0/16 accept comment "Guest to Internet only"
      }

      chain forward {
        type filter hook forward priority 0;
        policy drop;
        ct state established,related accept
        accept
      }
    }
  '';
}

