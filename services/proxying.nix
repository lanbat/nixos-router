{ config, pkgs, lib, ... }:

let
  proxyDataDir = "/var/lib/reverse-proxy";
in {
  containers.proxying = {
    autoStart = true;
    ephemeral = false;
    privateNetwork = true;
    hostAddress = "192.168.30.8"; # Management/Monitoring VLAN
    localAddress = "192.168.30.9";
    interfaces = [ "vlan30" ];
    bindMounts = {
      "${proxyDataDir}" = {
        hostPath = "/mnt/persist/reverse-proxy";
        isReadOnly = false;
      };
    };

    config = {
      systemd.services.podman-reverse-proxy = {
        description = "NGINX Reverse Proxy Container";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = ''
            ${pkgs.podman}/bin/podman run --rm --name reverse-proxy \
              -p 80:80 -p 443:443 \
              -v ${proxyDataDir}:/etc/nginx/conf.d:ro \
              docker.io/library/nginx
          '';
          Restart = "always";
        };
      };
    };
  };
}

