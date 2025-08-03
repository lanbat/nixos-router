{ config, pkgs, lib, ... }:

let
  inherit (import ./variables.nix) vlans wanInterface localDomain;
  blocklistDir = "/mnt/persist/blocklists";
  nft = "${pkgs.nftables}/bin/nft";
in
{
  networking.firewall.enable = false; # We use custom nftables instead

  systemd.services.nftables = {
    description = "Custom nftables firewall";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "setup-nftables" ''
        set -e
        ${nft} flush ruleset

        ${nft} add table inet filter

        ${nft} add chain inet filter input { type filter hook input priority 0\; policy drop\; }
        ${nft} add chain inet filter forward { type filter hook forward priority 0\; policy drop\; }
        ${nft} add chain inet filter output { type filter hook output priority 0\; policy accept\; }

        # Accept loopback and already established
        ${nft} add rule inet filter input iif lo accept
        ${nft} add rule inet filter input ct state established,related accept

        # Global allow: SSH to management VLAN
        ${nft} add rule inet filter input iifname "mgmtbr" tcp dport 22 accept

        # WireGuard
        ${nft} add rule inet filter input udp dport 51820 accept

        # Per-VLAN rules (example)
        ${nft} add rule inet filter forward iifname "svcbr" oifname "mainbr" tcp dport { 53, 67, 123 } accept
        ${nft} add rule inet filter forward iifname "iotbr" oifname "mediabr" accept
        ${nft} add rule inet filter forward iifname "guestbr" oifname "${wanInterface}" accept
        ${nft} add rule inet filter forward iifname "guestbr" oifname != "${wanInterface}" drop
        ${nft} add rule inet filter forward iifname "isolbr" oifname "svcbr" ip daddr 192.168.60.10 accept # to yellow
        ${nft} add rule inet filter forward iifname "isolbr" oifname != "svcbr" drop

        # Blocklists
        for list in ${blocklistDir}/*.nft; do
          ${nft} -f "$list"
        done
      '';
    };
  };

  systemd.tmpfiles.rules = [
    "d ${blocklistDir} 0755 root root -"
  ];
}

