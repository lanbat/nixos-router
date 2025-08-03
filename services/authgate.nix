{ config, pkgs, lib, ... }:

let
  inherit (import ../networking/variables.nix) localDomain authgateServices authgatePublicServices vlans;

  containerIP = "192.168.${toString vlans.services.id}.6";
  sambaCerts = "/mnt/samba/certs";
  sharedBase = "/mnt/shared";
  vaultwardenSecretPath = "/mnt/vaultwarden/secrets";

  isPublic = name: builtins.elem name authgatePublicServices;

  mkOauth2Config = name: {
    listen = "127.0.0.1:418${toString (builtins.hashString "sha256" name).charCodeAt(0) % 100}";
    upstream = "http://${name}.${localDomain}";
    provider = "keycloak";
    extra_args = {
      email_domains = [ "*" ];
      pass_authorization_header = true;
      set_authorization_header = true;
      scope = "openid email profile groups";
      cookie_secure = false;
    };
  };

  mkNginxBlock = name: ''
    server {
      listen ${if isPublic name then "80" else "127.0.0.1:80"};
      server_name ${name}.${localDomain};

      location / {
        proxy_pass http://127.0.0.1:418${toString (builtins.hashString "sha256" name).charCodeAt(0) % 100};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      }
    }
  '';

  mkCaddyBlock = name: ''
    ${name}.${localDomain} {
      reverse_proxy 127.0.0.1:80
      encode gzip
      tls {
        on_demand
      }
    }
  '';
in
{
  environment.etc."authgate/oauth2-config.json".text = builtins.toJSON {
    providers = {
      keycloak = {
        provider = "keycloak";
        client_id = "authgate";
        client_secret_path = "${vaultwardenSecretPath}/authgate-client-secret.txt";
        oidc_issuer_url = "https://keycloak.${localDomain}/realms/nixos";
      };
    };

    services = lib.listToAttrs (map (svc: {
      name = svc;
      value = mkOauth2Config svc;
    }) authgateServices);
  };

  environment.etc."authgate/nginx.conf".text = ''
    events {}
    http {
      ${lib.concatStringsSep "\n" (map mkNginxBlock authgateServices)}
    }
  '';

  environment.etc."authgate/Caddyfile".text =
    lib.concatStringsSep "\n\n" (
      map mkCaddyBlock authgatePublicServices
    );

  # Certificates for nginx
  environment.etc."ssl".source = "${sambaCerts}/authgate";

  systemd.services.authgate = {
    description = "Authgate Container";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = ''
        ${pkgs.podman}/bin/podman run --rm --network=bridge \
          --name authgate \
          --ip=${containerIP} \
          -v /etc/authgate:/config:ro \
          -v /etc/ssl:/ssl:ro \
          -v ${vaultwardenSecretPath}:/secrets:ro \
          docker.io/your/authgate-image
      '';
      Restart = "on-failure";
    };
  };

  # Metrics port and firewall rules (optional)
  networking.firewall.allowedTCPPorts = lib.mkIf (authgatePublicServices != [ ]) [ 80 443 ];
}

