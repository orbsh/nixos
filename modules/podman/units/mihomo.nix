{ pkgs, dataDir, user, ... }: {
  virtualisation.oci-containers.containers = {
    mihomo = {
      image = "ghcr.io/fj0r/xy:mihomo";
      volumes = [ "${dataDir}/ladder/mihomo:/data" ];
      ports = [
        "7890:7890"
        "7891:7891"
        "9090:9090"
      ];
      autoStart = true;
    };
  };

  systemd.services.podman-mihomo = {
    # 确保挂载目录存在
    preStart = ''
      mkdir -p ${dataDir}/ladder/mihomo
    '';

    # 镜像拉取失败时不阻塞系统启动（portable 可能需要先连网才能拉取）
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
