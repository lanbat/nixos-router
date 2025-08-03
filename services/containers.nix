{ config, pkgs, lib, ... }:

let
  inherit (import ../networking/variables.nix) localDomain vlans containerSpecs authgatePublicServices;
  sharedBase = "/mnt/shared";
  sambaCerts = "/mnt/samba/certs";

  containerDefaults = name: vlanList: hostPorts: bind127: image: mounts: {
    autoStart = true;
    execConfig = {
      image = image;
      hostname = "${name}.${localDomain}";
      restartPolicy = "always";
      extraOptions =
        [ "--network=none" ]
        ++ lib.optional bind127 "--publish=127.0.0.1:${hostPorts}"
        ++ lib.optional (!bind127 && hostPorts != null) "--publish=${hostPorts}";
      mounts = mounts;
      environment = {
        CERT_PATH = "/certs/fullchain.pem";
        KEY_PATH = "/certs/privkey.pem";
      };
    };
    dnsConfig = {
      hostname = "${name}.${localDomain}";
      powerdnsSync = true;
    };
  };

  certPaths = [
    "${sambaCerts}/services"
    "${sambaCerts}/hidden-services"
  ] ++ (map (vlan: "${sambaCerts}/${vlan.name}.${localDomain}") (lib.attrValues vlans))
    ++ (map (name: "${sambaCerts}/public/${authgatePublicServices.${name}}") (builtins.attrNames authgatePublicServices));

  containerMounts = name: shared: samba: certPaths: shared ++ [ "${samba}:/certs:ro" ] ++ certPaths;

  containerNames = builtins.attrNames containerSpecs;

  containerEntries = builtins.listToAttrs (map (name:
    let
      spec = containerSpecs.${name};
      resolvedVLANs = map (v: vlans.${v}) spec.vlans;
      mounts = containerMounts name ["${sharedBase}/${name}:/data:z"] "${sambaCerts}/${name}" certPaths;
    in {
      name = name;
      value = containerDefaults name resolvedVLANs spec.port spec.bind127 spec.image mounts;
    }) containerNames);

  systemdUnits = builtins.concatLists (map (name: [
    {
      "name" = "restart-${name}.service";
      "text" = ''
        [Unit]
        Description=Restart container ${name} on cert update
        [Service]
        Type=oneshot
        ExecStart=${pkgs.podman}/bin/podman restart ${name}
      '';
    }
    {
      "name" = "watch-${name}.path";
      "text" = ''
        [Unit]
        Description=Watch cert path for ${name}
        [Path]
        PathChanged=${sambaCerts}/${name}
        PathChanged=${sambaCerts}/services
        PathChanged=${sambaCerts}/hidden-services
        '' + builtins.concatStringsSep "\n" (map (vlan: "PathChanged=${sambaCerts}/${vlan.name}.${localDomain}") (lib.attrValues vlans)) +
        "\n" + builtins.concatStringsSep "\n" (map (s: "PathChanged=${sambaCerts}/public/${s}") (builtins.attrValues authgatePublicServices)) + ''
        Unit=restart-${name}.service
        [Install]
        WantedBy=multi-user.target
      '';
    }
  ]) containerNames);

in
{
  virtualisation.podman.enable = true;

  virtualisation.oci-containers.containers = containerEntries;

  systemd.services = builtins.listToAttrs (map (u: {
    name = u.name;
    value = { text = u.text; }; }) (filter (u: u.name hasSuffix ".service") systemdUnits));

  systemd.paths = builtins.listToAttrs (map (u: {
    name = u.name;
    value = { text = u.text; }; }) (filter (u: u.name hasSuffix ".path") systemdUnits));

  # Systemd containers (e.g. DHCP, Samba AD) will be configured in their own service files
}

