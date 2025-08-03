{ config, pkgs, lib, ... }:

{
  localDomain = "nixos.lan";
  physicalNic = "eno1";
  subnetPrefix = "192.168.";

  vpnSubnets = [
    "10.0.0.0/24"
    "10.9.0.0/24"
  ];

  vlans = {
    management = {
      id = 10;
      name = "management";
      cidr = "192.168.10.0/24";
      description = "Admin and NixOS control VLAN";
    };
    services = {
      id = 70;
      name = "services";
      cidr = "192.168.70.0/24";
      description = "Infrastructure service containers";
    };
    isolated = {
      id = 99;
      name = "isolated";
      cidr = "192.168.99.0/24";
      description = "Isolated Tor/I2P containers";
    };
  };

  trustedVLANsForCerts = [ "management" "services" ];

  suricataVLANs = [ "iot" "guests" ];

  vlanDnsBlocklists = {
    management = "extreme";
    services   = "ultimate";
    media      = "pro";
    iot        = "multi";
    guests     = "extreme";
  };

  sambaCertMounts = {
    keycloak = [ "/srv/samba/certs/keycloak:/certs:ro" ];
    authgate = [ "/srv/samba/certs/authgate:/certs:ro" ];
    deluge = [ "/srv/samba/certs/deluge:/certs:ro" ];
    bitmagnet = [ "/srv/samba/certs/bitmagnet:/certs:ro" ];
    shinobi = [ "/srv/samba/certs/shinobi:/certs:ro" ];
    homeassistant = [ "/srv/samba/certs/homeassistant:/certs:ro" ];
  };

  sharedMounts = {
    keycloak = [ "/mnt/shared/keycloak:/data:z,rw" ];
    authgate = [ "/mnt/shared/authgate:/config:z,rw" ];
    deluge = [ "/mnt/shared/torrents:/downloads:z,rw" ];
    bitmagnet = [ "/mnt/shared/torrents:/data:z,rw" ];
    shinobi = [ "/mnt/shared/shinobi:/config:z,rw" ];
    homeassistant = [ "/mnt/shared/homeassistant:/config:z,rw" ];
    #vaultwarden = [ "/mnt/shared/vaultwarden:/data:z,rw" ];
  };

  # OAuth2-protected services (need FreeIPA group membership and/or IP filter)
  authgateOAuth2Services = [
    {
      name = "vaultwarden";
      ip = "192.168.70.4";
      port = 8222;
      allowedGroups = [ "admins" "devs" ];
      allowedIPs = [ "192.168.10.0/24" ];
    }
    {
      name = "homeassistant";
      ip = "192.168.70.5";
      port = 8123;
      allowedGroups = [ "homeusers" ];
      allowedIPs = [ "192.168.20.0/24" ];
    }
  ];

  # Private services (IP filtering only, no OAuth)
  authgatePrivateServices = [
    {
      name = "internal-metrics";
      ip = "192.168.70.7";
      port = 9090;
      allowedIPs = [ "192.168.10.0/24" ];
    }
  ];

  # Public services (some may also be in OAuth2 list, with additional group+IP filtering)
  authgatePublicServices = [
    {
      name = "status";
      ip = "192.168.70.6";
      port = 8080;
      allowedIPs = [ "0.0.0.0/0" ];
    }
  ];

  authgateServices = [
    "vaultwarden"
    "homeassistant"
    "internal-metrics"
    "status"
  ];

}

