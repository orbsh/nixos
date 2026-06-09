{ pkgs, dataDir, user, ... }: {
  virtualisation.oci-containers.containers = {
    gitea = {
      image = "gitea/gitea:1.26";
      volumes = [
        "${dataDir}/gitea/data:/data"
      ];
      environment = {
        "GITEA__database__DB_TYPE" = "postgres";
        "GITEA__database__HOST" = "host.containers.internal:5332";
        "GITEA__database__NAME" = "gitea";
        "GITEA__database__USER" = "gitea";
        "GITEA__database__PASSWD" = "gitea";
        "GITEA__webhook__ALLOWED_HOST_LIST" = "ci-eventsource-svc";
      };
      ports = [
        "3333:3000"
        "3322:22"
      ];
      # 使用独立网络 + 固定 IP
      extraOptions = [ "--network" "app-net" "--ip" "10.89.0.102" ];
      autoStart = true;
    };

    gitea-pg = {
      image = "postgres:18";
      volumes = [
        "${dataDir}/gitea/pg18:/var/lib/postgresql"
        "${dataDir}/gitea/backup:/backup"
      ];
      environment = {
        "POSTGRES_DB" = "gitea";
        "POSTGRES_USER" = "gitea";
        "POSTGRES_PASSWORD" = "gitea";
      };
      ports = [
        "5332:5432"
      ];
      extraOptions = [ "--network" "app-net" "--ip" "10.89.0.101" ];
      autoStart = true;
    };
  };

  systemd.services.podman-gitea-pg = {
    preStart = ''
      mkdir -p ${dataDir}/gitea/pg18
      mkdir -p ${dataDir}/gitea/backup
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

  systemd.services.podman-gitea = {
    preStart = ''
      mkdir -p ${dataDir}/gitea/data
    '';

    # 确保 gitea 在 gitea-pg 之后启动
    after = [ "podman-gitea-pg.service" "podman-app-network.target" ];
    requires = [ "podman-gitea-pg.service" "podman-app-network.target" ];

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
