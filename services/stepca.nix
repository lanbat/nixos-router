{ config, pkgs, lib, ... }:

let
  inherit (import ../networking/variables.nix) vlans localDomain subnetPrefix;

  stepCaDir = "/var/lib/step-ca";
  sambaCertsPath = "/srv/samba/certs";
  secretsPath = "/mnt/vaultwarden/secrets";

in
{
  environment.systemPackages = [ pkgs.step-ca ];

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

  # Timer to check and renew expiring certificates
  systemd.services.renew-expiring-certs = {
    description = "Check for expiring certs and trigger renewal";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "renew-expiring-certs" ''
        set -euo pipefail

        expiry_threshold_days=7
        now=$(date +%s)

        for cert in $(find ${stepCaDir}/certs/issued -name fullchain.pem); do
          expiry=$(openssl x509 -enddate -noout -in "$cert" | cut -d= -f2)
          expiry_ts=$(date -d "$expiry" +%s || true)
          remaining_days=$(( (expiry_ts - now) / 86400 ))

          if [ "$remaining_days" -lt "$expiry_threshold_days" ]; then
            echo "[INFO] Certificate $cert is expiring soon. Triggering renewal."
            systemctl start generate-all-certs.service
            break
          fi
        done
      '';
    };
  };

  systemd.timers.renew-expiring-certs = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10min";
      OnUnitActiveSec = "6h";
      Unit = "renew-expiring-certs.service";
    };
  };
}

