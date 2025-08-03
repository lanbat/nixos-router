{ config, pkgs, lib, ... }:

let
  inherit (import ../networking/variables.nix)
    localDomain vlans authgatePublicServices;

  stepCaDir = "/var/lib/step-ca";
  issuedDir = "${stepCaDir}/certs/issued";
  sambaCertsPath = "/srv/samba/certs";

  # List of certs to generate
  wildcardDomains = builtins.concatLists (
    builtins.attrValues (
      lib.mapAttrs (
        vlanName: vlan: [ "*.${vlanName}.${localDomain}" ]
      ) vlans
    )
  );

  hiddenServiceDomains = [
    "*.onion"
    "*.i2p"
  ];

  publicServiceDomains = builtins.attrValues authgatePublicServices;

  allDomains = wildcardDomains ++ hiddenServiceDomains ++ publicServiceDomains;

  certScript = pkgs.writeShellScript "generate-certs.sh" ''
    set -euo pipefail
    mkdir -p ${issuedDir}

    for domain in ${lib.concatStringsSep " " allDomains}; do
      targetDir="${issuedDir}/$domain"
      mkdir -p "$targetDir"
      # Only generate if missing or expired
      if [ ! -f "$targetDir/fullchain.pem" ] || [ $(step certificate inspect "$targetDir/fullchain.pem" --expiry | date -d $(cat) +%s) -lt $(date +%s) ]; then
        step ca certificate "$domain" "$targetDir/fullchain.pem" "$targetDir/key.pem" \
          --provisioner admin --provisioner-password-file /mnt/vaultwarden/secrets/stepca-password.txt
      fi
    done
  '';

in {
  systemd.services.generate-certs = {
    description = "Generate certs for wildcard, public, and hidden services";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = certScript;
    };
  };

  # Daily renewal
  systemd.timers.generate-certs = {
    description = "Renew service certificates daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}

