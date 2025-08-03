{ config, pkgs, lib, ... }:

let
  ipaDataDir = "/var/lib/freeipa";
in {
  containers.ipa = {
    autoStart = true;
    ephemeral = false;
    privateNetwork = true;
    hostAddress = "192.168.10.2"; # Management VLAN
    localAddress = "192.168.10.3";
    interfaces = [ "vlan10" ];
    bindMounts = {
      "${ipaDataDir}" = {
        hostPath = "/mnt/persist/freeipa";
        isReadOnly = false;
      };
    };

    config = {
      systemd.services.podman-freeipa = {
        description = "FreeIPA Server container";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = ''
            ${pkgs.podman}/bin/podman run --rm --name freeipa-server \
              -h ipa.localdomain --ip=192.168.10.3 \
              -v ${ipaDataDir}:/data:Z \
              -e IPA_SERVER_IP=192.168.10.3 \
              -e IPA_SERVER_HOSTNAME=ipa.localdomain \
              -e IPA_DOMAIN=localdomain \
              -e IPA_REALM=LOCALDOMAIN \
              -e IPA_PASSWORD=admin123 \
              -p 80:80 -p 443:443 -p 389:389 -p 636:636 \
              docker.io/freeipa/freeipa-server:rocky-9
          '';
          Restart = "always";
        };
      };
    };
  };
}

