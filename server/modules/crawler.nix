{
  config,
  pkgs,
  lib,
  ...
}:

{
  # DuckDB with crawler extension for grocery price scraping
  # Data is stored in DuckLake format on Hetzner StorageBox via WebDAV

  environment.systemPackages = with pkgs; [
    duckdb
    davfs2 # WebDAV filesystem
  ];

  # WebDAV mount for StorageBox (DuckLake parquet storage)
  fileSystems."/mnt/storagebox" = {
    device = "https://placeholder.your-storagebox.de/";
    fsType = "davfs";
    options = [
      "noauto"
      "user"
      "rw"
      "_netdev"
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"
    ];
  };

  # davfs2 secrets (populated by systemd service from /var/lib/secrets)
  environment.etc."davfs2/secrets" = {
    mode = "0600";
    text = "# Managed by setup-storagebox.service";
  };

  # Service to configure WebDAV credentials from deployment secrets
  systemd.services.setup-storagebox = {
    description = "Setup StorageBox WebDAV credentials";
    wantedBy = [ "multi-user.target" ];
    before = [ "crawler.timer" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      if [ -f /var/lib/secrets/storagebox.env ]; then
        source /var/lib/secrets/storagebox.env

        # Update davfs2 secrets
        echo "https://$STORAGEBOX_SERVER.your-storagebox.de/ $STORAGEBOX_SERVER $STORAGEBOX_PASSWORD" > /etc/davfs2/secrets
        chmod 600 /etc/davfs2/secrets

        # Update fstab entry with actual server
        sed -i "s|https://placeholder.your-storagebox.de/|https://$STORAGEBOX_SERVER.your-storagebox.de/|" /etc/fstab

        # Create DuckLake directory structure
        mkdir -p /mnt/storagebox/ducklake/{catalog,data}
      fi
    '';
  };

  # Crawler service - runs through gluetun VPN proxy
  systemd.services.crawler = {
    description = "DuckDB Grocery Price Crawler";
    after = [
      "network-online.target"
      "gluetun.service"
      "setup-storagebox.service"
    ];
    wants = [ "network-online.target" ];
    requires = [ "gluetun.service" ];

    environment = {
      # Use gluetun as HTTP proxy for crawling
      HTTP_PROXY = "http://127.0.0.1:8888";
      HTTPS_PROXY = "http://127.0.0.1:8888";
      DUCKLAKE_PATH = "/mnt/storagebox/ducklake";
    };

    serviceConfig = {
      Type = "oneshot";
      User = "crawler";
      Group = "crawler";
      WorkingDirectory = "/var/lib/crawler";

      # Security hardening
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadWritePaths = [
        "/var/lib/crawler"
        "/mnt/storagebox"
      ];
    };

    script = ''
      # Ensure storagebox is mounted
      mount /mnt/storagebox || true

      # Initialize DuckLake if needed
      ${pkgs.duckdb}/bin/duckdb <<EOF
        INSTALL ducklake;
        LOAD ducklake;
        INSTALL crawler;
        LOAD crawler;

        -- Attach DuckLake with WebDAV storage
        ATTACH 'ducklake:$DUCKLAKE_PATH/catalog/open2log.sqlite' AS lake (
          DATA_PATH '$DUCKLAKE_PATH/data'
        );

        -- Create schema if not exists
        CREATE SCHEMA IF NOT EXISTS lake.products;
        CREATE SCHEMA IF NOT EXISTS lake.prices;
        CREATE SCHEMA IF NOT EXISTS lake.shops;
      EOF

      # Run crawlers (will be expanded with actual pipeline scripts)
      echo "Crawler service ready - pipelines will be added"
    '';
  };

  # Timer for scheduled crawling
  systemd.timers.crawler = {
    description = "Run grocery price crawler daily";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnCalendar = "daily";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };

  # Crawler user
  users.users.crawler = {
    isSystemUser = true;
    group = "crawler";
    home = "/var/lib/crawler";
    createHome = true;
  };

  users.groups.crawler = { };
}
