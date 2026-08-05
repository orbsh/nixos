{ dataDir, user, ... }: {
  virtualisation.oci-containers.containers = {
    qbittorrent = {
      image = "superng6/qbittorrentee:latest";
      environment = {
        "PUID" = "1000";
        "PGID" = "1000";
        "UMASK" = "002";
        "TZ" = "Etc/UTC";
        "QBT_WEBUI_PORT" = "8181";
        "QBT_TORRENTING_PORT" = "6881";
      };
      volumes = [
        "/home/${user}/data/qbittorrent/data:/config"
        "/home/${user}/Downloads/qbittorrent:/downloads"
      ];
      ports = [
        "8181:8080"    # Web UI
        "6881:6881"    # Torrenting (TCP)
        "6881:6881/udp" # Torrenting (UDP)
      ];
      autoStart = true;
    };
  };

  systemd.services.podman-qbittorrent = {
    preStart = ''
      mkdir -p /home/${user}/data/qbittorrent
      mkdir -p /home/${user}/Downloads/qbittorrent

      # ── 清理 stale 单实例锁 ─────────────────────────────
      # qBittorrent 用 lockfile + ipc-socket 做单实例检测。
      # 若上次异常退出（进程被杀/容器重启）会残留引用已不存在 PID 的锁，
      # 导致下次启动时误判"已有实例"而立即自我退出，陷入崩溃重启循环。
      # preStart 在容器启动前执行（此时容器必然未运行），删除残留锁安全。
      rm -f \
        /home/${user}/data/qbittorrent/data/qBittorrent/config/lockfile \
        /home/${user}/data/qbittorrent/data/qBittorrent/config/ipc-socket
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
