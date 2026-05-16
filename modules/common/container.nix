{ pkgs, lib, ... }: {
  imports = [
    ../../config/registries.nix  # 容器镜像仓库配置
  ];

  # ── Podman ───────────────────────────────────────────────
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;   # `docker` -> `podman` alias
    dockerSocket.enable = true;  # 开发工具（如 Devcontainers）需要读取此套接字
    defaultNetwork.settings.dns_enabled = true;
  };

  # ── Containerd ───────────────────────────────────────────
  virtualisation.containerd = {
    enable = false;          # 默认禁用
    settings = {
      plugins."io.containerd.grpc.v1.cri" = {
        sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9";
        registry.mirrors = {
          "registry.k8s.io" = { endpoint = ["https://registry.aliyuncs.com/google_containers"]; };
          "docker.io" = { endpoint = ["https://docker.lizzie.fun"]; };
        };
      };
    };
  };


  # Podman storage 配置（路径放在 /root 下）
  environment.etc."containers/storage.conf".text = lib.mkForce ''
    [storage]
    driver = "overlay"
    runroot = "/root/.local/share/containers/storage/runroot"
    graphroot = "/root/.local/share/containers/storage"
  '';
  # ── Container Image Tools ───────────────────────────────
  environment.systemPackages = with pkgs; [
    buildah
    skopeo
  ];
}
