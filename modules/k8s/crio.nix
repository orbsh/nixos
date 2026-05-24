# CRI-O 容器运行时配置
{ pkgs, lib, config, ... }:
let
  registriesData = import ../../config/registries.nix;

  generateRegistriesConf = import ../../lib/registries-gen.nix {
    inherit lib;
    cfg = registriesData;
  };
in {
  # ── 启用 CRI-O ──────────────────────────────────────────
  virtualisation.cri-o.enable = true;

  # ── CRI-O 运行时设置 ────────────────────────────────────
  virtualisation.cri-o = {
    runtime = "crun";
    settings.crio = {
      image.default_transport = "docker://";
    };
  };

  # ── CLI 工具 ────────────────────────────────────────────
  environment.systemPackages = with pkgs; [ cri-tools ];

  # ── kubelet pre-start：使用 crictl 加载 pause 镜像 ─────
  systemd.services.kubelet.preStart = lib.mkForce ''
    mkdir -p /var/lib/kubelet
    if ! ${pkgs.cri-tools}/bin/crictl pull registry.aliyuncs.com/google_containers/pause:3.10.1 2>/dev/null; then
      echo "Warning: failed to pull pause image, kubelet may retry"
    fi
  '';

  # ── 加载 Kubernetes 镜像到 CRI-O ────────────────────────
  systemd.services.load-k8s-images-crio = {
    description = "Load Kubernetes images into CRI-O";
    before = [ "kubelet.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      for img in ${config.services.kubernetes.package}/images/*.tar.gz; do
        echo "Loading image: $img"
        ${pkgs.podman}/bin/podman load -i "$img" 2>/dev/null || echo "Failed to load $img"
      done
    '';
  };

  # ── 容器镜像仓库配置（/etc/containers/registries.conf）──
  environment.etc."containers/registries.conf".text = lib.mkForce generateRegistriesConf;
}
