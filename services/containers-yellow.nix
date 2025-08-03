{ config, pkgs, lib, ... }:

let
  inherit (import ../networking/variables.nix)
    vlans
    localDomain
    subnetPrefix;

  yellowIP = "${subnetPrefix}${toString vlans.isolated.id}.5";
  squidCertPath = "/mnt/shared/certs/yellow";
in
{
  containers.yellow = {
    autoStart = true;
    ephemeral = false;
    privateNetwork = true;
    hostBridge = "br-${toString vlans.isolated.id}";
    localAddress = yellowIP;

    config = { config, pkgs, ... }: {
      networking.firewall.allowedTCPPorts = [ 3128 3129 ];
      networking.firewall.allowedUDPPorts = [ ];

      systemd.services.squid = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig.ExecStart = ''
          ${pkgs.squid}/sbin/squid -N -f /etc/squid/squid.conf
        '';
      };

      environment.etc = {
        "squid/squid.conf".text = ''
          http_port 3128
          https_port 3129 cert=/etc/squid/certs/fullchain.pem key=/etc/squid/certs/privkey.pem

          acl onion dstdomain .onion
          acl i2p dstdomain .i2p

          # Allow requests for onion/i2p only
          http_access allow onion
          http_access allow i2p
          http_access deny all

          # Forward to Tor SOCKS and I2P HTTP proxies
          cache_peer tor.isolated.${localDomain} parent 9050 0 proxy-only no-query
          cache_peer_access tor.isolated.${localDomain} allow onion

          cache_peer i2p.isolated.${localDomain} parent 4444 0 proxy-only no-query
          cache_peer_access i2p.isolated.${localDomain} allow i2p

          cache deny all
          never_direct allow all
          always_direct deny all
        '';

        "squid/certs/fullchain.pem".source = "${squidCertPath}/fullchain.pem";
        "squid/certs/privkey.pem".source = "${squidCertPath}/privkey.pem";
      };
    };
  };
}

