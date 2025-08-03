{ config, pkgs, lib, ... }:

let
  inherit (import ./variables.nix) physicalNic;
in
{
  systemd.services.qos-setup = {
    description = "QoS setup with tc";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "qos-setup" ''
        set -e

        IFACE="${physicalNic}"

        # Clear existing rules
        tc qdisc del dev $IFACE root || true

        # Root qdisc
        tc qdisc add dev $IFACE root handle 1: htb default 30

        # Define root class (full bandwidth)
        tc class add dev $IFACE parent 1: classid 1:1 htb rate 1000mbit

        # Guest VLAN - low priority
        tc class add dev $IFACE parent 1:1 classid 1:10 htb rate 100mbit ceil 200mbit prio 2
        tc filter add dev $IFACE protocol ip parent 1:0 prio 1 u32 match ip src 192.168.40.0/24 flowid 1:10

        # Torrent traffic - capped
        tc class add dev $IFACE parent 1:1 classid 1:20 htb rate 100mbit ceil 400mbit prio 1
        tc filter add dev $IFACE protocol ip parent 1:0 prio 2 u32 match ip src 192.168.50.4 flowid 1:20  # deluge
        tc filter add dev $IFACE protocol ip parent 1:0 prio 2 u32 match ip src 192.168.60.4 flowid 1:20  # deluge-isolated

        # Isolated VLAN - preferred inbound (assumes return traffic will be shaped elsewhere)
        tc class add dev $IFACE parent 1:1 classid 1:30 htb rate 300mbit ceil 600mbit prio 0
        tc filter add dev $IFACE protocol ip parent 1:0 prio 3 u32 match ip src 192.168.60.0/24 flowid 1:30
      '';
    };
  };
}

