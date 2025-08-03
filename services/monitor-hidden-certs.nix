{ config, pkgs, lib, ... }:

{
  systemd.paths.generate-hidden-certs-watch = {
    description = "Watch hidden service certs for changes";
    pathConfig = {
      PathModified = "/var/lib/step-ca/certs/issued/onion";
      PathModified_1 = "/var/lib/step-ca/certs/issued/i2p";
    };
    unitConfig = {
      Unit = "generate-hidden-certs.service";
    };
    wantedBy = [ "multi-user.target" ];
  };
}

