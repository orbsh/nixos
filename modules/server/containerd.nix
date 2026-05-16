# Containerd 容器运行时配置
{ lib, ... }:
let
  registriesData = import ../../config/registries.nix;
in {
  # ── 启用 Containerd ─────────────────────────────────────
  virtualisation.containerd.enable = true;

  # ── 禁用 podman（Containerd 模式下不需要）───────────────
  virtualisation.podman.enable = lib.mkForce false;

  # ── CLI 工具（nerdctl 兼容 Docker 命令）─────────────────
  environment.systemPackages = [ config.virtualisation.containerd.package nerdctl ];

  # ── Containerd 运行时设置 ───────────────────────────────
  virtualisation.containerd.settings = {
    plugins."io.containerd.grpc.v1.cri" = {
      sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9";

      # ── 镜像仓库配置（Containerd 原生格式）─────────────
      registry = {
        # 代理镜像（mirrors）
        mirrors = lib.mapAttrs (_prefix: location: {
          endpoint = [ location ];
        }) registriesData.proxyRegistries;

        # 非安全镜像（跳过 TLS 验证）
        configs = builtins.listToAttrs (map (loc: {
          name = loc;
          value = {
            tls = {
              insecure_skip_verify = true;
            };
          };
        }) registriesData.insecureRegistries);
      };
    };
  };
}
