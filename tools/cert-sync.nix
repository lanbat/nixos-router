{ config, pkgs, lib, ... }:

let
  stepCaDir = "/var/lib/step";
  hostname = "yellow";
  fqdn = "${hostname}.${import ../networking/variables.nix}.localDomain";
  certsOut = "/var/lib/step/certs";
  keysOut = "/var/lib/step/private";

in
{
  systemd.services.step-ca = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.step-ca}/bin/step-ca ${stepCaDir}/config/ca.json --password-file ${stepCaDir}/secrets/password";
      WorkingDirectory = stepCaDir;
      Restart = "always";
    };
  };

  environment.systemPackages = with pkgs; [ step-ca ];

  system.activationScripts.stepCaInit = lib.stringAfter [
    "mkdir -p ${stepCaDir}/config"
    "mkdir -p ${stepCaDir}/secrets"
    "mkdir -p ${certsOut}"
    "mkdir -p ${keysOut}"
    "chown -R step-ca:step-ca ${stepCaDir}"
  ] "setup-stepca";

  users.groups.step-ca = {};
  users.users.step-ca = {
    isSystemUser = true;
    group = "step-ca";
    home = stepCaDir;
    createHome = false;
  };

  # Firewall rule for step-ca if needed
  networking.firewall.allowedTCPPorts = [ 9000 ]; # or whichever port step-ca is bound to

  systemd.services.cert-sync = {
    description = "Copy step-ca certs to Samba share";
    after = [ "step-ca.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "sync-certs" ''
        set -e
        for crt in ${certsOut}/*.crt; do
          base=$(basename "$crt" .crt)
          key="${keysOut}/$base.key"
          dest="/srv/samba/certs/$base"
          mkdir -p "$dest"
          cp "$crt" "$dest/fullchain.pem"
          cp "$key" "$dest/privkey.pem"
          chown -R samba:samba "$dest"
        done
      '';
    };
  };

  systemd.timers.cert-sync-timer = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      Unit = "cert-sync.service";
    };
  };
} 

