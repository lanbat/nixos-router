{ config, pkgs, lib, ... }:

let
  inherit (import ../networking/variables.nix)
    localDomain
    vlans
    authgatePublicServices
    authgatePrivateServices
    authgateOAuth2Services;

  # Consolidate services
  allServices = builtins.concatLists [ authgatePublicServices authgatePrivateServices authgateOAuth2Services ];

  mkServerBlock = service: let
    isOAuth = builtins.elem service authgateOAuth2Services;
    isPublic = builtins.elem service authgatePublicServices;
    isPrivate = builtins.elem service authgatePrivateServices;

    allowIPs = lib.optionals (isPublic || isPrivate) (service.allowedIPs or []);
    allowGroups = lib.optionals isOAuth (service.allowedGroups or []);
    host = "${service.name}.${localDomain}";
  in ''
    server {
      listen 443 ssl;
      server_name ${host};

      ssl_certificate /etc/caddy/certs/${host}.crt;
      ssl_certificate_key /etc/caddy/certs/${host}.key;

      ${lib.optionalString (isOAuth) ''
        location / {
          include /etc/nginx/oauth2-proxy.conf;
          proxy_pass http://${service.ip}:${toString service.port};
        }
      ''}

      ${lib.optionalString (!isOAuth) ''
        location / {
          proxy_pass http://${service.ip}:${toString service.port};
        }
      ''}

      ${lib.optionalString (allowIPs != []) ''
        allow ${lib.concatStringsSep ";\n    allow " allowIPs};
        deny all;
      ''}
    }
  '';
in
{
  networking.firewall.allowedTCPPorts = [ 443 ];
  networking.firewall.allowedUDPPorts = [ ];

  systemd.services.authgate = {
    description = "Authgate NGINX Proxy";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = ''
        ${pkgs.nginx}/bin/nginx -c /etc/nginx/nginx.conf -g 'daemon off;'
      '';
      Restart = "always";
    };
  };

  environment.etc."nginx/nginx.conf".text = ''
    worker_processes 1;
    events {
      worker_connections 1024;
    }
    http {
      include       mime.types;
      default_type  application/octet-stream;

      sendfile        on;
      keepalive_timeout  65;

      ${lib.concatStringsSep "\n\n" (map mkServerBlock allServices)}
    }
  '';

  # Certificates should be placed by Caddy
  systemd.tmpfiles.rules = [
    "d /etc/caddy/certs 0755 root root -"
  ];
}

