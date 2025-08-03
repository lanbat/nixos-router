{ pkgs, lib, callPackage, ... }:

let
  vars = import ../networking/variables.nix;

  servicesVlan = vars.vlans.services;
  mediaVlan = vars.vlans.media;
  mgmtVlan = vars.vlans.management;

  subnetPrefix = vars.subnetPrefix;
  localDomain = vars.localDomain;
  domain = "ad.${localDomain}";

  getVlanIp = id: "${subnetPrefix}${toString id}";
in
{
  name = "nixos-multivlan-full";

  nodes = {
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

  testScript = ''
    import re

    start_all()

    router.wait_for_unit("multi-user.target")
    client.wait_for_unit("dhcpcd.service")

    # ✅ DHCP & DNS
    client.succeed("ip a | grep '${getVlanIp servicesVlan.id}'")
    client.succeed("dig +short client.${localDomain} @${getVlanIp servicesVlan.id}.2")
    client.succeed("dig -x ${getVlanIp servicesVlan.id}.10 @${getVlanIp servicesVlan.id}.2")
    client.succeed("ping -c1 router.${localDomain}")

    # ✅ WireGuard
    vpnClient.succeed(\"\"\"
      ip link add dev wg0 type wireguard &&
      ip address add dev wg0 10.0.0.2/24 &&
      ip link set wg0 up &&
      wg set wg0 private-key <(echo PRIVATEKEY) peer PEER_PUBKEY allowed-ips 0.0.0.0/0 endpoint ${getVlanIp servicesVlan.id}.1:51820 &&
      ping -c1 10.0.0.1
    \"\"\")

    # ✅ Samba certs
    client.succeed("mount -t cifs //${getVlanIp mgmtVlan.id}.6/certs /mnt -o user=guestwifi,vers=3.0")
    client.succeed("test -f /mnt/fullchain.pem")

    # ✅ FreeIPA
    client.succeed("kinit -V administrator@${domain.upper()}")

    # ✅ Mullvad routing (simulated)
    client.succeed("curl --interface mullvad http://ifconfig.me")
  '';
}

