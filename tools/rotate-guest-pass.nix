{ config, pkgs, lib, ... }:

let
  vaultPath = "/mnt/vaultwarden/secrets/guestwifi.txt";
  ipaUser = "guestwifi";
  ipaAdminUser = "admin";
  ipaAdminPasswordFile = "/mnt/vaultwarden/secrets/ipa-admin-pass.txt";

  rotateScript = pkgs.writeShellScript "rotate-guest-pass" ''
    set -eu

    # Generate a strong password
    new_pass=$(openssl rand -base64 18)

    # Authenticate to FreeIPA
    kinit ${ipaAdminUser} < ${ipaAdminPasswordFile}

    # Change guestwifi password
    echo -e "${new_pass}\n${new_pass}" | ipa passwd ${ipaUser}

    # Write new password to Vaultwarden path
    echo "$new_pass" > ${vaultPath}

    # Cleanup
    kdestroy
  '';
in
{
  systemd.services.rotate-guest-pass = {
    description = "Rotate FreeIPA guestwifi password daily";
    script = rotateScript;
    serviceConfig = {
      Type = "oneshot";
    };
  };

  systemd.timers.rotate-guest-pass = {
    description = "Daily guestwifi password rotation";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      AccuracySec = "1min";
    };
  };
}

