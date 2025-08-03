containers.vaultwarden = {
  vlan = "services";
  hostname = "vaultwarden.${localDomain}";
  image = "vaultwarden/server:latest";
  authgate = {
    enable = true;
    public = false;
  };
  mounts = {
    data = "/mnt/shared/vaultwarden/data";
    config = "/mnt/shared/vaultwarden/config";
    certs = "/srv/samba/certs/vaultwarden.${localDomain}";
  };
  env = {
    WEBSOCKET_ENABLED = "true";
    ROCKET_PORT = "8080";
    DATABASE_URL = "postgresql://vaultwarden:${secrets.vaultwardenPostgresPassword}@postgres.services.${localDomain}/vaultwarden";
    DOMAIN = "https://vaultwarden.${localDomain}";
    SIGNUPS_ALLOWED = "false";
    SMTP_HOST = "mail.${localDomain}";
    SMTP_FROM = "vaultwarden@${localDomain}";
    SMTP_PORT = "587";
    SMTP_SSL = "true";
    SMTP_USERNAME = "vaultwarden@${localDomain}";
    SMTP_PASSWORD = secrets.vaultwardenSmtpPassword;
  };
  expose = {
    ports = [ 8080 ]; # Only bind to 127.0.0.1, authgate handles external access
    listenLocalhost = true;
  };
};

