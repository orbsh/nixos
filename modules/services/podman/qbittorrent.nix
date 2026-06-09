{ dataDir, user, ... }: {
  virtualisation.oci-containers.containers = {
    qbittorrent = {
      image = "qbittorrentofficial/qbittorrent-nox";
      environment = {
        "PUID" = "1000";
        "PGID" = "1000";
        "UMASK" = "002";
        "TZ" = "Etc/UTC";
        "QBT_WEBUI_PORT" = "8181";
        "QBT_TORRENTING_PORT" = "6881";
      };
      volumes = [
        "/home/${user}/.config/qbittorrent/config:/config"
        "/home/${user}/Downloads/qbittorrent/downloads:/downloads"
      ];
      ports = [
        "8181:8181"    # Web UI
        "6881:6881"    # Torrenting (TCP)
        "6881:6881/udp" # Torrenting (UDP)
      ];
      autoStart = true;
    };
  };

  systemd.services.podman-qbittorrent = {
    preStart = ''
      mkdir -p /home/${user}/.config/qbittorrent/config
      mkdir -p /home/${user}/Downloads/qbittorrent/downloads
    '';

    after = [ "podman-app-network.target" ];
    requires = [ "podman-app-network.target" ];

    unitConfig = {
      StartLimitBurst = 3;
      StartLimitIntervalSec = 60;
    };
    serviceConfig = {
      RestartSec = "10s";
      Restart = "on-failure";
    };
    wantedBy = [ "multi-user.target" "default.target" ];
  };
}
