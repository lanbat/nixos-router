{ config, lib, pkgs, ... }:

let
  scriptPath = "/etc/wireguard/sync-wg-peers.sh";
  outputJson = "/mnt/vaultwarden/secrets/wireguard/peers.json";
  ipaGroups = [ "vpn-services" "vpn-media" "vpn-iot" "vpn-guests" ];
  vpnSubnet = "10.0.0";

  syncScript = pkgs.writeShellScript "sync-wg-peers" ''
    set -euo pipefail
    tmpfile=$(mktemp)
    echo "{" > "$tmpfile"
    ipIndex=2

    for group in ${lib.concatStringsSep " " ipaGroups}; do
      members=$(ipa group-show "$group" --all --raw | grep 'member_user:' | awk '{print $2}')
      for user in $members; do
        pubkey=$(ipa user-show "$user" --all --raw | grep wgPublicKey | cut -d ':' -f 2 | xargs || true)
        if [[ -n "$pubkey" ]]; then
          ip="${vpnSubnet}.$ipIndex"
          echo "  \"$user\": { \"publicKey\": \"$pubkey\", \"groups\": [\"$group\"], \"ip\": \"$ip\" }," >> "$tmpfile"
          ipIndex=$((ipIndex + 1))
        fi
      done
    done

    sed -i '$ s/},/}/' "$tmpfile"
    echo "}" >> "$tmpfile"
    mv "$tmpfile" ${outputJson}
  '';

in {
  systemd.services.wg-peer-sync = {
    description = "Sync WireGuard peer list from FreeIPA";
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${syncScript}";
    };
  };

  systemd.timers.wg-peer-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "12h";
    };
  };
}

