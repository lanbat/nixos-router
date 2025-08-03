{ config, pkgs, lib, ... }:

let
  prometheusDataDir = "/var/lib/prometheus2";
  grafanaDataDir = "/var/lib/grafana";
  lokiDataDir = "/var/lib/loki";
in {
  containers.monitoring = {
    autoStart = true;
    ephemeral = false;
    privateNetwork = true;
    hostAddress = "192.168.30.2"; # Monitoring VLAN IP
    localAddress = "192.168.30.3";
    interfaces = [ "vlan30" ];
    bindMounts = {
      "${prometheusDataDir}" = {
        hostPath = "/mnt/persist/prometheus";
        isReadOnly = false;
      };
      "${grafanaDataDir}" = {
        hostPath = "/mnt/persist/grafana";
        isReadOnly = false;
      };
      "${lokiDataDir}" = {
        hostPath = "/mnt/persist/loki";
        isReadOnly = false;
      };
      "/mnt/vaultwarden/secrets/grafana-admin-password" = {
        hostPath = "/mnt/vaultwarden/secrets/grafana-admin-password";
        isReadOnly = true;
      };
      "/mnt/vaultwarden/secrets/oauth2-proxy-client-secret" = {
        hostPath = "/mnt/vaultwarden/secrets/oauth2-proxy-client-secret";
        isReadOnly = true;
      };
    };

    config = {
      systemd.services.podman-prometheus = {
        description = "Prometheus container";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = ''
            ${pkgs.podman}/bin/podman run --rm --name prometheus \
              -p 9090:9090 \
              -v ${prometheusDataDir}:/prometheus \
              docker.io/prom/prometheus
          '';
          Restart = "always";
        };
      };

      systemd.services.podman-grafana = {
        description = "Grafana container";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = ''
            ${pkgs.podman}/bin/podman run --rm --name grafana \
              -p 3000:3000 \
              -v ${grafanaDataDir}:/var/lib/grafana \
              -e "GF_SECURITY_ADMIN_PASSWORD__FILE=/mnt/vaultwarden/secrets/grafana-admin-password" \
              docker.io/grafana/grafana
          '';
          Restart = "always";
        };
      };

      systemd.services.podman-loki = {
        description = "Loki container";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = ''
            ${pkgs.podman}/bin/podman run --rm --name loki \
              -p 3100:3100 \
              -v ${lokiDataDir}:/loki \
              docker.io/grafana/loki
          '';
          Restart = "always";
        };
      };
    };
  };
}

