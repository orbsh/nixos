{ pkgs, dataDir, ... }: {
  virtualisation.oci-containers.containers = {
    mihomo = {
      image = "ghcr.io/fj0r/xy:mihomo";
      volumes = [ "${dataDir}/mihomo:/data" ];
      ports = [
        "7890:7890"
        "7891:7891"
        "9090:9090"
      ];
      extraOptions = [ "--restart=always" ];
      autoStart = true;
    };
  };

  # 等效于 Quadlet 的 WantedBy=multi-user.target default.target
  systemd.services.podman-mihomo.wantedBy = [ "multi-user.target" "default.target" ];
}