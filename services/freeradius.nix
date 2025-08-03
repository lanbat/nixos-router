{ config, pkgs, lib, ... }:

let
  vars = import ../networking/variables.nix;
  radiusDataDir = "/var/lib/freeradius";
  radiusImage = "freeradius/freeradius-server:latest";
  vlan = vars.vlans.management;
  managementHost = builtins.replaceStrings [".0/24"] [".6"] vlan.cidr;
  managementLocal = builtins.replaceStrings [".0/24"] [".7"] vlan.cidr;
  vlanInterface = "vlan${toString vlan.id}";

in {
  containers.freeradius = {
    autoStart = true;
    ephemeral = false;
    privateNetwork = true;
    hostAddress = managementHost;
    localAddress = managementLocal;
    interfaces = [ vlanInterface ];

    bindMounts = {
      "${radiusDataDir}" = {
        hostPath = "/mnt/persist/freeradius";
        isReadOnly = false;
      };
    };

    config = {
      systemd.services.podman-freeradius = {
        description = "FreeRADIUS server in a Podman container";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = ''
            ${pkgs.podman}/bin/podman run \
              --rm \
              --name freeradius \
              -p 1812:1812/udp \
              -p 1813:1813/udp \
              -v ${radiusDataDir}:/etc/raddb \
              ${radiusImage}
          '';
          Restart = "always";
        };
      };
    };
  };
}

