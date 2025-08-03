{ config, pkgs, lib, ... }:

{

  imports = [
    ./hardware-configuration.nix
    ./networking/variables.nix
    ./networking/vlans.nix
    ./networking/suricata.nix

    ./services/dhcp.nix
    ./services/pdns.nix
    ./services/firewall.nix
    ./services/qos.nix
    ./services/monitoring.nix
    ./services/vpn.nix
    ./services/wg-peer-generate.nix  

    ./services/ipa.nix
    ./services/samba-ad.nix
    ./services/freeradius.nix

    ./services/stepca.nix
    ./services/generate-certs.nix
    ./services/cert-sync.nix

    ./tools/wg-peer-sync.nix
    ./tools/torrent-routing.nix

    ./services/containers.nix
    ./services/containers-tor.nix
    ./services/containers-i2p.nix
    ./services/containers-yellow.nix
    ./services/authgate.nix
    ./services/filesharing.nix
    ./services/proxying.nix

    ./services/vaultwarden.nix
    ./services/keycloak.nix

    # Optional: Final docs (not a Nix file, but tracked)
    # ./doc/README.md
  ];

  networking.hostName = "nixos-router";
  networking.useDHCP = false;

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  console.keyMap = "uk";

  # Enable Podman + Docker compatibility
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  # System-wide secrets from Vaultwarden
  environment.etc."vaultwarden-secrets".source = "/mnt/vaultwarden/secrets";

  # Enable fish shell
  programs.fish.enable = true;

  # Default user
  users.users.kiril = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.fish;
  };

  # Logging
  services.journald.extraConfig = ''
    SystemMaxUse=512M
    MaxRetentionSec=1month
  '';

  # Flakes + GC
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nixpkgs.config.allowUnfree = true;
}

