{ config, pkgs, lib, ... }:

let
  inherit (import ../networking/variables.nix) localDomain vlans;
  sharedBase = "/mnt/shared";
  sambaCerts = "/mnt/samba/certs";

  containerDefaults = name: vlan: hostPorts: bind127: mounts: {
    autoStart = true;
    execConfig = {
      hostname = "${name}.${vlan.name}.${localDomain}";
      restartPolicy = "always";
      extraOptions =
        [ "--network=none" ]
        ++ lib.optional bind127 "--publish=127.0.0.1:${hostPorts}"
        ++ lib.optional (!bind127 && hostPorts != null) "--publish=${hostPorts}";
      mounts = mounts;
      environment = {
        CERT_PATH = "/certs/fullchain.pem";
        KEY_PATH = "/certs/privkey.pem";
      };
    };
    dnsConfig = {
      hostname = "${name}.${vlan.name}.${localDomain}";
      powerdnsSync = true;
    };
  };
in
{
  virtualisation.podman.enable = true;

  virtualisation.oci-containers.containers = {
    homeassistant = containerDefaults "homeassistant" vlans.iot "8123:8123" true [
      "${sharedBase}/homeassistant:/config:z"
      "${sambaCerts}/homeassistant:/certs:ro"
    ];

    shinobi = containerDefaults "shinobi" vlans.iot "8080:8080" true [
      "${sharedBase}/shinobi:/config:z"
      "${sambaCerts}/shinobi:/certs:ro"
    ];

    deluge = containerDefaults "deluge" vlans.media "8112:8112" true [
      "${sharedBase}/torrents:/downloads:z"
      "${sambaCerts}/deluge:/certs:ro"
    ];

    bitmagnet = containerDefaults "bitmagnet" vlans.media null true [
      "${sharedBase}/torrents:/data:z"
      "${sambaCerts}/bitmagnet:/certs:ro"
    ];

    keycloak = containerDefaults "keycloak" vlans.services "8081:8081" true [
      "${sharedBase}/keycloak:/data:z"
      "${sambaCerts}/keycloak:/certs:ro"
    ];

    authgate = containerDefaults "authgate" vlans.services null true [
      "${sharedBase}/authgate:/config:z"
      "${sambaCerts}/authgate:/certs:ro"
    ];

    vaultwarden = containerDefaults "vaultwarden" vlans.services "8222:80" true [
      "${sharedBase}/vaultwarden:/data:z"
    ];
  };

  # Systemd containers (e.g. DHCP, Samba AD) will be configured in their own service files
}

