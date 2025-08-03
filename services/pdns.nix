{ config, pkgs, lib, ... }:

let
  inherit (import ../networking/variables.nix)
    localDomain
    vlans
    vlanDnsBlocklists
    authgateServices
    publicServices
    subnetPrefix;

  dnsServerIP = "${subnetPrefix}${toString vlans.services.id}.2";
  sambaAdDomain = "ad.${localDomain}";
  sambaAdIP     = "${subnetPrefix}${toString vlans.services.id}.10";
  authgateIP    = "${subnetPrefix}${toString vlans.services.id}.6";
  yellowIP      = "${subnetPrefix}${toString vlans.isolated.id}.4";

  reverseZones = builtins.map (vlan:
    let subnet = subnetPrefix + toString vlan.id;
    in {
      zone = lib.replaceStrings [ "." "/" ] [ "" "" ] "${lib.concatStringsSep "." (lib.reverseList (lib.splitString "." subnet))}.in-addr.arpa";
      cidr = "${subnet}.0/24";
    }
  ) (builtins.attrValues vlans);

  allInternalVlanIPs = builtins.map (vlan: "${subnetPrefix}${toString vlan.id}.2") (builtins.attrValues vlans);

  makeSOA = fqdn: nsIP: ''
    $TTL 1h
    @ IN SOA ${fqdn}. root.${localDomain}. (2025080301 1h 15m 1w 1h)
      IN NS ${fqdn}.
    ${fqdn}. IN A ${nsIP}
  '';

  genAuthgateRecords = ip: services:
    lib.concatStringsSep "\n" (
      builtins.map (name: "${name} IN A ${ip}") services
    );
in
{
  networking.firewall.allowedTCPPorts = [ 53 ];
  networking.firewall.allowedUDPPorts = [ 53 ];

  services.powerdns = {
    enable = true;
    extraConfig = ''
      local-address=${lib.concatStringsSep "," allInternalVlanIPs}
      local-port=53
      default-zones-dir=/etc/pdns/zones
      allow-axfr-ips=127.0.0.1
      launch=bind
      setgid=pdns
      setuid=pdns
      log-dns-queries=yes
      loglevel=4
      dnssec=validate
      recursive-cache-ttl=60
      include-dir=/etc/pdns/zones/includes
    '';
  };

  services.pdns-recursor = {
    enable = true;
    luaConfigFile = "/etc/pdns/recursor.lua";
    forwardZones = {
      "${sambaAdDomain}" = sambaAdIP;
    };
    localAddress = allInternalVlanIPs;
    allowFrom = [ "127.0.0.1" ] ++ allInternalVlanIPs;
  };

  environment.etc = lib.mkMerge (
    [

      # Root internal zone
      {
        "pdns/zones/${localDomain}.zone".text =
          makeSOA "dns.${localDomain}" dnsServerIP + "\n" +
          genAuthgateRecords authgateIP authgateServices;
      }

      # Public zone
      {
        "pdns/zones/public.${localDomain}.zone".text =
          makeSOA "dns.public.${localDomain}" dnsServerIP + "\n" +
          genAuthgateRecords authgateIP publicServices;
      }

      # Wildcard .onion and .i2p zones
      {
        "pdns/zones/onion.zone".text = ''
          $TTL 1h
          @ IN SOA dns.${localDomain}. root.${localDomain}. (2025080301 1h 15m 1w 1h)
            IN NS dns.${localDomain}.
          *.onion. IN A ${yellowIP}
        '';

        "pdns/zones/i2p.zone".text = ''
          $TTL 1h
          @ IN SOA dns.${localDomain}. root.${localDomain}. (2025080301 1h 15m 1w 1h)
            IN NS dns.${localDomain}.
          *.i2p. IN A ${yellowIP}
        '';
      }

    ]

    ++

    # Per-VLAN zones
    (builtins.map (vlan: {
      "pdns/zones/${vlan.name}.${localDomain}.zone".text =
        makeSOA "dns.${vlan.name}.${localDomain}" "${subnetPrefix}${toString vlan.id}.2" + "\n" +
        genAuthgateRecords authgateIP (lib.filter (name: vlan.name == vlans.services.name) authgateServices);
    }) (builtins.attrValues vlans))

    ++

    # Reverse zones
    (builtins.map (rev: {
      "pdns/zones/${rev.zone}.zone".text = ''
        $TTL 1h
        @ IN SOA dns.${localDomain}. root.${localDomain}. (2025080301 1h 15m 1w 1h)
          IN NS dns.${localDomain}.
      '';
    }) reverseZones)

    ++

    # Recursor blocklist Lua
    [{
      "pdns/recursor.lua".text = ''
        local client_ip = pdns.remoteaddr:match("^(%d+%.%d+%.%d+)")
        function preresolve(dq)
          if not client_ip then return false end
          local blocklist_file = "/mnt/persist/dns-blocklists/" .. client_ip .. ".txt"
          local file = io.open(blocklist_file, "r")
          if not file then return false end
          for line in file:lines() do
            if dq.qtype == pdns.A and dq.qname:match(line) then
              dq:addAnswer(pdns.A, "0.0.0.0")
              return true
            end
          end
          file:close()
          return false
        end
      '';
    }]
  );

  # Dynamic DNS updates support
  services.pdns-dnsupdate = {
    enable = true;
    apiKey = "changeme"; # Secure via Vaultwarden in production
    apiURL = "http://your-upstream-pdns-server.example.com:8081";
    recordDomain = "public.${localDomain}";
  };
}

