
{
  systemd.services.tor-container = {
    description = "Tor Proxy Container";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      ExecStart = ''
        ${pkgs.podman}/bin/podman run --rm \
          --name tor \
          --network bridge \
          --cap-add=NET_ADMIN \
          -v /var/lib/tor/torrc:/etc/tor/torrc:ro \
          -v /var/lib/tor:/var/lib/tor \
          docker.io/torproxy:latest \
          tor -f /etc/tor/torrc
      '';
      Restart = "on-failure";
    };
  };
}
