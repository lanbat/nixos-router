{ config, pkgs, lib, ... }:

let
  mountPoint = "/mnt/samba/certs";
  certInstallPath = "/usr/local/share/ca-certificates/custom";
in
{
  systemd.mounts.samba-certs = {
    description = "Mount Samba certs share";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    before = [ "install-certs.service" ];
    mountConfig = {
      What = "//dc1.ad.nixos.lan/certs";
      Where = mountPoint;
      Type = "cifs";
      Options = "ro,guest,vers=3.0";
    };
  };

  systemd.services.install-certs = {
    description = "Install certificates from Samba share";
    after = [ "samba-certs.mount" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "install-certs" ''
        set -euxo pipefail
        mkdir -p ${certInstallPath}

        find ${mountPoint} -type f -name '*.pem' -exec cp -f {} ${certInstallPath}/ \;
        update-ca-certificates
      '';
    };
  };

  systemd.timers.install-certs = {
    description = "Periodic cert install from Samba share";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}

