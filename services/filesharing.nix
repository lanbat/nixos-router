{ config, pkgs, lib, ... }:

let
  fileshareDataDir = "/srv/files";
in
{
  services.samba = {
    enable = true;
    shares = {
      downloads = {
        path = "${fileshareDataDir}/downloads";
        comment = "Group shared downloads";
        browseable = true;
        writeable = true;
        guestOk = false;
        createMask = "0660";
        directoryMask = "0770";
        validUsers = "@downloads";
      };

      media = {
        path = "${fileshareDataDir}/media";
        comment = "Shared media (read-only)";
        browseable = true;
        writeable = false;
        guestOk = true;
      };

      homes = {
        path = "${fileshareDataDir}/homes";
        comment = "Per-user home directories";
        browseable = false;
        writeable = true;
        guestOk = false;
      };
    };

    extraConfig = ''
      vfs objects = acl_xattr
      map acl inherit = yes
      store dos attributes = yes
      follow symlinks = yes
      wide links = yes
      unix extensions = no
      log level = 1
      smb1 disabled = yes
    '';
  };

  # Setup directories and ACLs
  systemd.tmpfiles.rules = [
    "d ${fileshareDataDir}/downloads 0770 root downloads -"
    "d ${fileshareDataDir}/media 0755 root root -"
    "d ${fileshareDataDir}/homes 0700 root root -"
  ];

  # Enable user quotas
  boot.kernelModules = [ "quota_v2" ];
  fileSystems."/srv/files" = {
    device = "/dev/disk/by-label/fileshare";
    fsType = "btrfs";
    options = [ "defaults" "usrquota" "grpquota" ];
  };

  services.quota = {
    enable = true;
    userQuotaEnable = true;
    groupQuotaEnable = true;
    quotaPartitions = [ "/srv/files" ];
  };
}

