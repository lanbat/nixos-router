{ config, pkgs, lib, ... }:

let
  inherit (import ../networking/variables.nix) localDomain keycloakRealm vlans;
  vlan = vlans.services;
  pgsqlIP = "192.168.${toString vlan.id}.9";
  keycloakIP = "192.168.${toString vlan.id}.8";
  pgsqlPasswordFile = "/mnt/vaultwarden/secrets/keycloak-db-pass.txt";
  adminPasswordFile = "/mnt/vaultwarden/secrets/keycloak-admin-pass.txt";

  realmJson = pkgs.writeText "keycloak-realm.json" (builtins.toJSON {
    realm = keycloakRealm.name;
    enabled = true;
    clients = builtins.attrValues (builtins.mapAttrs (_: client:
      {
        clientId = client.name or _;
        redirectUris = client.redirectUris;
        publicClient = client.publicClient or false;
        secret = client.secretFile != null
          then builtins.readFile client.secretFile
          else null;
      }
    ) keycloakRealm.clients);
  });
in
{
  virtualisation.oci-containers.containers = {
    postgresql = {
      image = "docker.io/library/postgres:16";
      autoStart = true;
      ports = [ "${pgsqlIP}:5432:5432" ];
      environment = {
        POSTGRES_DB = "keycloak";
        POSTGRES_USER = "keycloak";
        POSTGRES_PASSWORD_FILE = pgsqlPasswordFile;
      };
      volumes = [ "/mnt/shared/keycloak/pgdata:/var/lib/postgresql/data" ];
      extraOptions = [ "--network=bridge" "--ip=${pgsqlIP}" ];
    };

    keycloak = {
      image = "quay.io/keycloak/keycloak:24.0";
      autoStart = true;
      ports = [ "127.0.0.1:8081:8080" ];  # admin only on loopback
      volumes = [
        "/mnt/shared/keycloak:/opt/keycloak/data"
        "${realmJson}:/config/realm.json"
      ];
      environment = {
        KEYCLOAK_ADMIN = "admin";
        KEYCLOAK_ADMIN_PASSWORD_FILE = adminPasswordFile;
        KC_DB = "postgres";
        KC_DB_URL_HOST = pgsqlIP;
        KC_DB_URL_DATABASE = "keycloak";
        KC_DB_USERNAME = "keycloak";
        KC_DB_PASSWORD_FILE = pgsqlPasswordFile;
        KEYCLOAK_IMPORT = "/config/realm.json";
        KC_HTTP_RELATIVE_PATH = "/";  # Needed if using authgate
        KC_PROXY_HEADERS = "forwarded";
      };
      extraOptions = [ "--network=bridge" "--ip=${keycloakIP}" ];
    };
  };

  # Keycloak DNS record
  networking.extraHosts = ''
    ${keycloakIP} keycloak.${localDomain}
  '';
}

