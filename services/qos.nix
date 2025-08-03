# QoS via nftables for VLANs and torrent shaping
{ config, pkgs, lib, ... }:

let
  subnetPrefix = "192.168";
  ifaces = {
    guest = "br50";
    isolated = "br60";
    media = "br40";
    main = "br20";
  };
in {
  networking.nftables.enable = true;

  systemd.services."qos-setup" = {
    description = "QoS nftables rules setup";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "setup-qos" ''
        set -eux

        nft add table inet qos || true
        nft flush table inet qos

        nft add chain inet qos ingress { type filter hook ingress device ${ifaces.guest} priority -500; }
        nft add chain inet qos postrouting { type nat hook postrouting priority 100; }

        nft add rule inet qos ingress meta l4proto tcp counter mark set 0x10
        nft add rule inet qos ingress meta l4proto udp counter mark set 0x10

        # Limit isolated VLAN to 60% egress bandwidth (on Mullvad)
        tc qdisc add dev ${ifaces.isolated} root handle 1: htb default 30
        tc class add dev ${ifaces.isolated} parent 1: classid 1:1 htb rate 60mbit ceil 60mbit

        # Cap torrent traffic to 40% bandwidth
        tc qdisc add dev ${ifaces.media} root handle 1: htb default 20
        tc class add dev ${ifaces.media} parent 1: classid 1:1 htb rate 40mbit ceil 40mbit
      '';
    };
  };
}

