{ config, pkgs, lib, ... }:

let
  inherit (import ../networking/variables.nix) vlans localDomain subnetPrefix;
  dnsServer = "192.168.70.2";
  leaseTime = "604800"; # 7 days
  staticLeases = import ./static-leases.nix;
in
{
  networking.firewall.allowedUDPPorts = [ 67 ]; # DHCP

  services.isc-dhcp-server = {
    enable = true;
    interfaces = builtins.map (vlan: "${vlan.name}br") (builtins.attrValues vlans);

    extraConfig = ''
      default-lease-time ${leaseTime};
      max-lease-time ${leaseTime};

      one-lease-per-client true;
      authoritative;
      log-facility local7;

      option domain-name "${localDomain}";
      option domain-name-servers ${dnsServer};
    '' + lib.concatStringsSep "\n" (builtins.map (vlan:
      let
        subnet = "${subnetPrefix}${toString vlan.id}";
        router = "${subnet}.1";
        rangeStart = "${subnet}.100";
        rangeEnd = "${subnet}.199";
        bridge = "${vlan.name}br";
      in ''
        subnet ${subnet}.0 netmask 255.255.255.0 {
          option routers ${router};
          range ${rangeStart} ${rangeEnd};
        }
      ''
    ) (builtins.attrValues vlans)) + "\n\n" + staticLeases.config;
  };

  systemd.services.dhcp-postlease-hook = {
    description = "DHCP Hook to update PowerDNS after lease commit";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "pdns-lease-hook" ''
        #!/bin/bash
        LEASES="/var/lib/dhcp/dhcpd.leases"
        HOOK_SCRIPT="/etc/pdns/hooks/lease-sync.sh"
        if [ -x "$HOOK_SCRIPT" ]; then
          $HOOK_SCRIPT "$LEASES"
        fi
      '';
    };
  };
}

