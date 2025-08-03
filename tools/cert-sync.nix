{ config, lib, pkgs, ... }:

let
  hostname = config.networking.hostName;
  sourceCertPath = "/etc/step-ca/certs";
  targetCertPath = "/srv/samba/certs/${hostname}";
  hiddenCertPath = "/srv/samba/certs/hidden-services";
  hiddenSourcePath = "/etc/step-ca/hidden";
in
{
  systemd.services.cert-sync = {
    description = "Sync TLS certificates to Samba share";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c ''
        mkdir -p ${targetCertPath}
        cp ${sourceCertPath}/fullchain.pem ${targetCertPath}/fullchain.pem
        cp ${sourceCertPath}/privkey.pem ${targetCertPath}/privkey.pem
        chmod 640 ${targetCertPath}/privkey.pem
        chmod 644 ${targetCertPath}/fullchain.pem
        chown root:users ${targetCertPath}/privkey.pem
        chown root:users ${targetCertPath}/fullchain.pem

        # Sync hidden service certs
        mkdir -p ${hiddenCertPath}
        for certdir in ${hiddenSourcePath}/*; do
          name=$(basename "$certdir")
          mkdir -p ${hiddenCertPath}/$name
          cp "$certdir/fullchain.pem" ${hiddenCertPath}/$name/
          cp "$certdir/privkey.pem" ${hiddenCertPath}/$name/
          chmod 640 ${hiddenCertPath}/$name/privkey.pem
          chmod 644 ${hiddenCertPath}/$name/fullchain.pem
          chown root:users ${hiddenCertPath}/$name/*.pem
        done
      ''";
    };
  };

  systemd.path.cert-sync-watch = {
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathModified = sourceCertPath;
      PathModified_1 = hiddenSourcePath;
    };
    unitConfig = {
      Unit = "cert-sync.service";
    };
  };
}

