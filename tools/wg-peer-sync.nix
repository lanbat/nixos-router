{ config, lib, pkgs, ipaGroups, vpnSubnet }:

# This version filters peers based on IPA group membership
# The JSON should be structured like:
# {
#   "alice": {
#     "publicKey": "...",
#     "groups": ["vpn-services", "vpn-media"],
#     "ip": "10.0.0.2"
#   },
#   ...
# }

let
  peerJsonPath = "/mnt/vaultwarden/secrets/wireguard/peers.json";
  rawJson = builtins.readFile peerJsonPath;
  peerMap = builtins.fromJSON rawJson;

  hasMatchingGroup = attrs: builtins.any (group: builtins.elem group ipaGroups) attrs.groups;

  filteredPeers = lib.filterAttrs (_: attrs: hasMatchingGroup attrs) peerMap;

  assignedPeers = lib.mapAttrs (_: attrs: {
    publicKey = attrs.publicKey;
    allowedIPs = [ "${attrs.ip}/32" ];
  }) filteredPeers;

in assignedPeers

