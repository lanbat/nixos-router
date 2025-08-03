{ config, pkgs, lib, ... }:

let
  inherit (import ../networking/variables.nix) vlans localDomain;
  vlan = vlans.services;
  sambaDomain = "ad";
  realm = "AD.${lib.toUpper localDomain}";
  fqdn = "dc1.${sambaDomain}.${localDomain}";
  bridgeName = "br${toString vlan.id}";
  sambaCertsPath = "/srv/samba/certs";
  adminPasswordFile = "/mnt/vaultwarden/secrets/samba-admin-pass.txt";
in
{
  containers.samba-ad = {
    autoStart = true;
    privateNetwork = true;
    hostBridge = bridgeName;
    localAddress = "192.168.${toString vlan.id}.10";

    config = {
      system.stateVersion = "24.05";

      networking = {
        firewall.allowedTCPPorts = [ 445 139 ];
        firewall.allowedUDPPorts = [ 137 138 ];
        hostName = "dc1";
        domain = "${sambaDomain}.${localDomain}";
      };

      services.samba = {
        enable = true;
        package = pkgs.sambaFull;

        provision = {
          realm = realm;
          domain = sambaDomain;
          adminPasswordFile = adminPasswordFile;
          serverRole = "dc";
          useNtdomains = false;
          dnsBackend = "NONE";  # PowerDNS handles DNS
        };

        shares = {
          certs = {
            path = sambaCertsPath;
            comment = "Certificate Authority Certs";
            browseable = true;
            guestOk = false;
            readOnly = true;
          };
        };

        extraConfig = ''
          workgroup = ${sambaDomain}
          realm = ${realm}
          server role = active directory domain controller
          kerberos method = secrets and keytab
          log level = 1
        '';
      };

      systemd.tmpfiles.rules = [
        "d ${sambaCertsPath} 0755 root root -"
      ];
    };
  };

  # Host-side folder to hold GPO content (SYSVOL staging)
  systemd.tmpfiles.rules = [
    "d /srv/samba/certs 0755 root root -"
    "d /srv/samba/sysvol 0755 root root -"
  ];

  # Template or script for generating GPOs
  environment.etc."gpo/install-certs.ps1".text = ''
    # Auto-install CA certs from Samba share on Windows clients
    $certPath = "\\\\${fqdn}\\certs"
    $certs = Get-ChildItem -Path $certPath -Recurse -Include *.pem

    foreach ($cert in $certs) {
      certutil -addstore -f "Root" $cert.FullName
    }
  '';
}

