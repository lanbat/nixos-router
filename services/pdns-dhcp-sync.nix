{ config, pkgs, lib, ... }:

let
  inherit (import ../networking/variables.nix) localDomain;
  apiKeyFile = "/mnt/vaultwarden/secrets/pdns-api-key";
  hostnameScript = pkgs.writeShellScript "generate-hostname" ''
    #!/bin/bash
    adj=$(shuf -n1 /usr/share/dict/adjectives)
    noun=$(shuf -n1 /usr/share/dict/nouns)
    echo "${adj}-${noun}.${localDomain}"
  '';

  syncScript = pkgs.writeShellScript "lease-sync.sh" ''
    #!/bin/bash
    LEASES="$1"
    PDNS_URL="http://127.0.0.1:8081/api/v1"
    API_KEY=$(cat ${apiKeyFile})
    
    extract_info() {
      grep -A5 "^lease " "$LEASES" | awk '
        /hardware ethernet/ { mac=$3 }
        /client-hostname/ { gsub("\"", "", $2); host=$2 }
        /lease / { if (ip) print ip, mac, host; ip=$2; host=""; mac="" }
      '
    }

    extract_info | while read ip mac host; do
      if [ -z "$host" ]; then
        host=$(${hostnameScript})
      fi
      shortname=$(echo $host | cut -d. -f1)

      # Create A and PTR records
      curl -s -X PATCH "$PDNS_URL/servers/localhost/zones/${localDomain}." \
        -H "X-API-Key: $API_KEY" -H "Content-Type: application/json" \
        -d @- <<EOF
{
  "rrsets": [
    {
      "name": "$host.",
      "type": "A",
      "ttl": 300,
      "changetype": "REPLACE",
      "records": [ { "content": "$ip", "disabled": false } ]
    }
  ]
}
EOF

      rev=$(echo $ip | awk -F. '{print $4"."$3"."$2"."$1".in-addr.arpa."}')
      curl -s -X PATCH "$PDNS_URL/servers/localhost/zones/${rev}" \
        -H "X-API-Key: $API_KEY" -H "Content-Type: application/json" \
        -d @- <<EOF
{
  "rrsets": [
    {
      "name": "$rev",
      "type": "PTR",
      "ttl": 300,
      "changetype": "REPLACE",
      "records": [ { "content": "$host.", "disabled": false } ]
    }
  ]
}
EOF

    done
  '';
in
{
  systemd.services.pdns-dhcp-sync = {
    description = "PowerDNS sync from DHCP leases";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${syncScript} /var/lib/dhcp/dhcpd.leases";
    };
  };

  systemd.timers.pdns-dhcp-sync = {
    description = "Periodic cleanup of stale PowerDNS entries";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };
}

