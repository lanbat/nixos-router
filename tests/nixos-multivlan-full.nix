{ pkgs, lib, callPackage, makeTest, ... }:

(makeTest {
  inherit pkgs lib callPackage;
}) {
  name = "nixos-multivlan-full";
  nodes = let
    vars = import ../networking/variables.nix;

    servicesVlan = vars.vlans.services;
    mediaVlan = vars.vlans.media;
    mgmtVlan = vars.vlans.management;

    subnetPrefix = vars.subnetPrefix;
    localDomain = vars.localDomain;
    domain = "ad.${localDomain}";

    getVlanIp = id: "${subnetPrefix}${toString id}";
  in {
    router = { config, ... }: {
      imports = [ ../configuration.nix ];
    };

    client = { config, pkgs, ... }: {
      networking.useDHCP = false;
      networking.interfaces.eth1.useDHCP = true;
    };

    vpnClient = { config, pkgs, ... }: {
      environment.systemPackages = [ pkgs.wireguard-tools ];
      networking.useDHCP = false;
    };
  };

  testScript = let
    vars = import ../networking/variables.nix;

    servicesVlan = vars.vlans.services;
    mgmtVlan = vars.vlans.management;

    subnetPrefix = vars.subnetPrefix;
    localDomain = vars.localDomain;
    domain = "ad.${localDomain}";

    getVlanIp = id: "${subnetPrefix}${toString id}";
  in ''
    import re

    start_all()

    router.wait_for_unit("multi-user.target")
    client.wait_for_unit("dhcpcd.service")

    # ✅ DHCP: Client gets IP from services VLAN
    client.succeed("ip a | grep '${getVlanIp servicesVlan.id}'")

    # ✅ DNS resolution
    client.succeed("dig +short client.${localDomain} @${getVlanIp servicesVlan.id}.2")

    # ✅ PTR record test (example IP from services VLAN)
    client.succeed("dig -x ${getVlanIp servicesVlan.id}.10 @${getVlanIp servicesVlan.id}.2")

    # ✅ Router A record
    client.succeed("ping -c1 router.${localDomain}")

    # ✅ WireGuard VPN test (mocked keys)
    vpnClient.succeed("""
      ip link add dev wg0 type wireguard &&
      ip address add dev wg0 10.0.0.2/24 &&
      ip link set wg0 up &&
      wg set wg0 private-key <(echo 8KQbNzn0G38zSY+M0TVsIq7PGvZ3oYZ1sOEa+b3mFVA=) peer F3jB/1vhb8XD24+VwMJQeaYc2wcrnPSkIetjvLaFdwE= allowed-ips 0.0.0.0/0 endpoint ${getVlanIp servicesVlan.id}.1:51820 &&
      ping -c1 10.0.0.1
    """)

    # ✅ Samba cert share
    client.succeed("mount -t cifs //${getVlanIp mgmtVlan.id}.6/certs /mnt -o user=guestwifi,vers=3.0")
    client.succeed("test -f /mnt/fullchain.pem")

    # ✅ FreeIPA auth
    client.succeed("kinit -V administrator@${lib.toUpper domain}")

    # ✅ Mullvad test (mockable)
    client.succeed("curl --interface mullvad http://ifconfig.me")
  '';
}

