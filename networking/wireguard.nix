{ config, pkgs, lib, ... }:

let
  inherit (import ../variables.nix) vpnSubnets wanInterface;
in
{
  networking.nat.enable = true;
  networking.nat.externalInterface = wanInterface;
  networking.nat.internalInterfaces = [ "wg0" ];

  networking.firewall.allowedUDPPorts = [ 51820 ]; # WireGuard port

  networking.wireguard.interfaces = {
    wg0 = {
      ips = [ "10.0.0.1/24" ];
      listenPort = 51820;
      privateKeyFile = "/mnt/vaultwarden/secrets/wg0-private.key";

      postSetup = ''
        iptables -t nat -A POSTROUTING -s ${vpnSubnets.remote} -o ${wanInterface} -j MASQUERADE
      '';
      postShutdown = ''
        iptables -t nat -D POSTROUTING -s ${vpnSubnets.remote} -o ${wanInterface} -j MASQUERADE
      '';

      # Peers are synced separately via wg-peer-sync
      peers = [ ];
    };

    mullvad = {
      # Assume config file was imported directly by systemd
      # We do not define keys here, only activate routing
      # This interface is handled by /etc/wireguard/mullvad.conf
    };
  };

  # Ensure Mullvad interface comes up
  systemd.services."wg-quick@mullvad".wantedBy = [ "multi-user.target" ];
}

