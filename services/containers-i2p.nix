# services/containers/i2p.nix

{ config, pkgs, lib, ... }:

let
  inherit (import ../../networking/variables.nix) localDomain vlans;
  isolatedVlan = vlans.isolated;
  containerName = "i2p";
  containerHostname = "${containerName}.${localDomain}";
  containerIP = "192.168.${toString isolatedVlan.id}.4";
in
{
  virtualisation.podman.enable = true;

  systemd.services."podman-${containerName}" = {
    description = "I2P container";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Restart = "always";
      ExecStart = ''
        ${pkgs.podman}/bin/podman run --rm \
          --name=${containerName} \
          --hostname=${containerHostname} \
          --network=none \
          --cap-add=NET_ADMIN \
          -v /var/lib/i2p/config:/home/i2p/.i2p \
          docker.io/meeh/i2p \
          /usr/bin/i2prouter start
      '';
      ExecStop = "${pkgs.podman}/bin/podman stop ${containerName}";
    };
  };

  systemd.network.networks."20-i2p-${containerName}" = {
    matchConfig.Name = "ve-i2p";
    networkConfig = {
      Address = "${containerIP}/24";
      DNS = "127.0.0.1";
    };
  };

  systemd.network.links."20-i2p-link" = {
    matchConfig.OriginalName = "ve-i2p";
    linkConfig.MTUBytes = 1400;
  };

  networking.interfaces."ve-i2p" = {
    ipv4.addresses = [{
      address = containerIP;
      prefixLength = 24;
    }];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/i2p/config 0755 root root -"
  ];
}

