{ config, lib, pkgs, inputs, ... }:

let
  vpnSubnet = "10.0.0.0/24";
  vpnServerIp = "10.0.0.1";
  mullvadInterface = "mullvad";
  vaultPath = "/mnt/vaultwarden/secrets/wireguard/server.json";
  mullvadConfPath = "/mnt/vaultwarden/secrets/wireguard/mullvad.conf";

in {
  networking.nat.enable = true;
  networking.nat.internalInterfaces = [ "wg0" ];
  networking.nat.externalInterface = config.networking.defaultGatewayInterface;

  networking.firewall.allowedUDPPorts = [ 51820 ];

  networking.wireguard.interfaces.wg0 = {
    ips = [ "${vpnServerIp}/24" ];
    listenPort = 51820;
    privateKeyFile = "${vaultPath}";

    peers = import ../tools/wg-peer-sync.nix {
      inherit config lib pkgs;
      ipaGroups = [
        "vpn-management"
        "vpn-services"
        "vpn-media"
        "vpn-iot"
        "vpn-guests"
      ];
      vpnSubnet = vpnSubnet;
    };
  };

  # Mullvad client interface (WireGuard)
  networking.wireguard.interfaces.${mullvadInterface} = {
    configFile = mullvadConfPath;
  };

  systemd.network.enable = true;

  # Ensure wg0 exists before activation
  systemd.services.ensure-wg0 = {
    wantedBy = [ "multi-user.target" ];
    before = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.iproute2}/bin/ip link add wg0 type wireguard";
      RemainAfterExit = true;
    };
  };
}

