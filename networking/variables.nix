{
  localDomain = "nixos.lan";
  physicalNic = "eno1";
  subnetPrefix = "192.168.";

  vlans = {
    management = {
      id = 10;
      name = "management";
      cidr = "192.168.10.0/24";
      description = "Admin-only systems, router web UI";
    };
    services = {
      id = 70;
      name = "services";
      cidr = "192.168.70.0/24";
      description = "Core containers like Home Assistant, Keycloak, Bitmagnet";
    };
    media = {
      id = 60;
      name = "media";
      cidr = "192.168.60.0/24";
      description = "Smart TVs, streaming clients, Jellyfin";
    };
    iot = {
      id = 50;
      name = "iot";
      cidr = "192.168.50.0/24";
      description = "Smart home devices, sensors, appliances";
    };
    guests = {
      id = 40;
      name = "guests";
      cidr = "192.168.40.0/24";
      description = "Guest Wi-Fi network with limited access";
    };
  };

  authgateServices = [
    "keycloak"
    "vaultwarden"
  ];

  authgatePublicServices = [
    "vaultwarden"
    "keycloak"
  ];

  vlanDnsBlocklists = {
    management = "none";
    services   = "ultimate";
    media      = "pro";
    iot        = "multi";
    guests     = "extreme";
  };

  vpnSubnets = [
    "10.0.0.0/24"
    "10.9.0.0/24"
  ];

  trustedVLANsForCerts = [
    "management"
    "services"
  ];

  suricataVLANs = [
    "iot"
    "guests"
  ];

}

