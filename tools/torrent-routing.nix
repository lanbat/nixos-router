{ config, pkgs, lib, ... }:

let
  vars = import ../networking/variables.nix;
  mediaVlan = vars.vlans.media;
  mainVlan = vars.vlans.services;

  sourceSubnets = [ mediaVlan.cidr mainVlan.cidr ];
  torrentInterface = ["vlan${toString mediaVlan.id}" "vlan${toString mainVlan.id}"]; # not used directly here but can be
  mullvadInterface = "mullvad";
  routeMark = "0x66";

  trackerIpFile = "/var/lib/torrent/tracker_ips.txt";

  markRules = builtins.concatStringsSep "\n" (
    map (subnet: "  ip saddr ${subnet} meta mark set ${routeMark}") sourceSubnets
  );

  ipsetName = "torrent_trackers";

in {
  environment.systemPackages = [ pkgs.curl pkgs.gawk ];

  systemd.services.download-torrent-trackers = {
    description = "Download and extract tracker IP list";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''
        mkdir -p /var/lib/torrent
        ${pkgs.curl}/bin/curl -sSfL https://raw.githubusercontent.com/ngosang/trackerslist/refs/heads/master/trackers_all_ip.txt \
          | ${pkgs.gawk}/bin/awk '$1 ~ /^[0-9.]+$/ { print $1 }' > ${trackerIpFile}
      '';
      ExecStartPost = "${pkgs.systemd}/bin/systemctl restart nftables.service";
    };
  };

  systemd.timers.download-torrent-trackers = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "24h";
    };
  };

  networking.nftables.enable = true;
  networking.nftables.tables.torrent-marking = {
    family = "inet";
    content = ''
      define ${ipsetName} = { include "${trackerIpFile}" }

      chain prerouting {
        type filter hook prerouting priority 0;
${markRules}
        ip daddr @${ipsetName} meta mark set ${routeMark}
      }
    '';
  };

  networking.extraRoutingRules = [
    {
      mark = 0x66;
      table = 110;
    }
  ];

  networking.routes = [
    {
      interface = mullvadInterface;
      destination = "0.0.0.0/0";
      table = 110;
    }
  ];
}

