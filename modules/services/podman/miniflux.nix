{ pkgs, dataDir, user, ... }: {
  virtualisation.oci-containers.containers = {
    miniflux = {
      image = "miniflux/miniflux:latest";
      volumes = [
        "${dataDir}/miniflux/data:/data"
      ];
      environment = {
        "DATABASE_URL" = "host=miniflux-pg port=5432 user=miniflux password=miniflux dbname=miniflux sslmode=disable";
        "RUN_MIGRATIONS" = "1";
        "CREATE_ADMIN" = "1";
        "ADMIN_USERNAME" = "admin";
        "ADMIN_PASSWORD" = "adminadmin";
        "BASE_URL" = "http://localhost:8090";
      };
      ports = [
        "8090:8080"
      ];
      # 使用独立网络 + 固定 IP
      extraOptions = [ "--network" "app-net" "--ip" "10.89.0.104" ];
      autoStart = true;
    };

    miniflux-pg = {
      image = "postgres:17";
      volumes = [
        "${dataDir}/miniflux/pg17:/var/lib/postgresql/data"
        "${dataDir}/miniflux/backup:/backup"
      ];
      environment = {
        "POSTGRES_DB" = "miniflux";
        "POSTGRES_USER" = "miniflux";
        "POSTGRES_PASSWORD" = "miniflux";
      };
      ports = [
        "5434:5432"
      ];
      extraOptions = [ "--network" "app-net" "--ip" "10.89.0.103" ];
      autoStart = true;
    };
  };

  systemd.services.podman-miniflux-pg = {
    preStart = ''
      mkdir -p ${dataDir}/miniflux/pg17
      mkdir -p ${dataDir}/miniflux/backup
    '';


    # 依赖 app-net 网络就绪
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

  systemd.services.podman-miniflux = {
    preStart = ''
      mkdir -p ${dataDir}/miniflux/data
    '';

    # 确保 miniflux 在 miniflux-pg 之后启动
    after = [ "podman-miniflux-pg.service" "podman-app-network.target" ];
    requires = [ "podman-miniflux-pg.service" "podman-app-network.target" ];

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
