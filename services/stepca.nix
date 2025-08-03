{ config, pkgs, lib, ... }:

let
  inherit (import ../networking/variables.nix) vlans localDomain subnetPrefix;

  stepCaDir = "/var/lib/step-ca";
  sambaCertsPath = "/srv/samba/certs";

  secretsPath = "/mnt/vaultwarden/secrets";
in
{
  # Install step-ca
  environment.systemPackages = [ pkgs.step-ca ];

  # Intermediate CA configuration and files
  systemd.services.step-ca = {
    description = "step-ca intermediate certificate authority";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.step-ca}/bin/step-ca ${stepCaDir}/config/ca.json --password-file ${secretsPath}/stepca-password.txt";
      Restart = "on-failure";
      User = "root";
    };

    preStart = ''
      mkdir -p ${stepCaDir}/config
      mkdir -p ${stepCaDir}/db
      cp -n ${secretsPath}/stepca-root.crt ${stepCaDir}/certs/root_ca.crt
      cp -n ${secretsPath}/stepca-intermediate.crt ${stepCaDir}/certs/intermediate_ca.crt
      cp -n ${secretsPath}/stepca-intermediate.key ${stepCaDir}/secrets/intermediate_ca_key
    '';
  };

  # Cert sync: copies certs from step-ca to Samba share
  systemd.services.sync-stepca-certs = {
    description = "Sync issued certificates to Samba certs share";
    script = ''
      set -euo pipefail

      mkdir -p ${sambaCertsPath}

      for hostname in $(ls ${stepCaDir}/certs/issued); do
        mkdir -p "${sambaCertsPath}/$hostname"
        cp -f ${stepCaDir}/certs/issued/$hostname/fullchain.pem "${sambaCertsPath}/$hostname/fullchain.pem"
        cp -f ${stepCaDir}/certs/issued/$hostname/key.pem "${sambaCertsPath}/$hostname/privkey.pem"
      done
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    wantedBy = [ "multi-user.target" ];
  };

  # Renew + Sync certs daily
  systemd.timers.sync-stepca-certs = {
    description = "Daily cert sync to Samba share";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}

