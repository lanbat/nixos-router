{ config, pkgs, lib, ... }:

let
  inherit (import ../networking/variables.nix) vlans vlanDnsBlocklists subnetPrefix;

  downloadScript = pkgs.writeShellScript "update-dns-blocklists" ''
    set -euo pipefail

    echo "Updating DNS blocklists..."

    mkdir -p /mnt/persist/dns-blocklists

    ${lib.concatStringsSep "\n" (builtins.attrValues (builtins.mapAttrs (vlanName: vlan: 
      let
        blocklist = vlanDnsBlocklists.${vlanName};
        subnet = subnetPrefix + toString vlan.id;
        ipPrefix = subnet;
        url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/${blocklist}.txt";
        dest = "/mnt/persist/dns-blocklists/${ipPrefix}.txt";
      in ''
        echo "Downloading blocklist for ${vlanName} from ${url}..."
        curl -fsSL "${url}" -o "${dest}.tmp" && mv "${dest}.tmp" "${dest}"
      ''
    ) vlans))}
  '';
in
{
  systemd.services.update-dns-blocklists = {
    description = "Download VLAN-specific DNS blocklists for PowerDNS";
    script = downloadScript;
    startAt = "*-*-* 04:00:00";  # Daily at 4am
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.timers.update-dns-blocklists = {
    description = "Timer for downloading DNS blocklists";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}

