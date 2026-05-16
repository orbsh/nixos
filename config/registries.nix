# 容器镜像仓库配置（CRI-O/podman 和 containerd 通用）
{ lib, ... }:
let
  # ── 非安全镜像列表 ───────────────────────────────────
  insecureRegistries = [
    "registry.s"
    "registry.d"
    "172.178.5.123:5000"
    "localhost:5000"
  ];

  # ── 代理镜像字典（prefix → location）─────────────────
  proxyRegistries = {
    "registry.k8s.io" = "registry.aliyuncs.com/google_containers";
    "docker.io" = "docker.lizzie.fun";
    "ghcr.io" = "ghcr.lizzie.fun";
  };
in {
  # ── 数据定义（只放数据，供模块消费）───────────────────
  options.containersCfg = {
    insecureRegistries = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = insecureRegistries;
      description = "非安全镜像仓库列表";
    };
    proxyRegistries = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = proxyRegistries;
      description = "代理镜像字典（prefix → location）";
    };
  };
}
