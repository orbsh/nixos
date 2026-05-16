# Containerd 容器运行时配置
{ lib, config, ... }:
let
  cfg = config.containersCfg;
in {
  # ── 启用 Containerd ─────────────────────────────────────
  virtualisation.containerd.enable = true;

  # ── Containerd 运行时设置 ───────────────────────────────
  virtualisation.containerd.settings = {
    plugins."io.containerd.grpc.v1.cri" = {
      sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9";

      # ── 镜像仓库配置（Containerd 原生格式）─────────────
      registry = {
        # 代理镜像（mirrors）
        mirrors = lib.mapAttrs (_prefix: location: {
          endpoint = [ location ];
        }) cfg.proxyRegistries;

        # 非安全镜像（跳过 TLS 验证）
        configs = builtins.listToAttrs (map (loc: {
          name = loc;
          value = {
            tls = {
              insecure_skip_verify = true;
            };
          };
        }) cfg.insecureRegistries);
      };
    };
  };
}
