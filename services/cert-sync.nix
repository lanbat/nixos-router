{ config, lib, pkgs, ... }:

let
  sourceCertBase = "/etc/step-ca/certs";
  targetCertBase = "/srv/samba/certs";
in
{
  systemd.services.cert-sync = {
    description = "Sync TLS certificates for all services to Samba share";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c ''
        shopt -s nullglob
        for dir in ${sourceCertBase}/*; do
          name=$(basename "$dir")
          targetDir=${targetCertBase}/$name
          mkdir -p "$targetDir"
          cp "$dir"/fullchain.pem "$targetDir"/fullchain.pem
          cp "$dir"/privkey.pem "$targetDir"/privkey.pem
          chmod 640 "$targetDir"/privkey.pem
          chmod 644 "$targetDir"/fullchain.pem
          chown root:users "$targetDir"/fullchain.pem "$targetDir"/privkey.pem
        done
      ''";
    };
  };

  systemd.path.cert-sync-watch = {
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathModified = "${sourceCertBase}";
      Unit = "cert-sync.service";
    };
  };

  # Ensure /srv/samba/certs exists
  systemd.tmpfiles.rules = [
    "d ${targetCertBase} 0750 root users -"
  ];
}

