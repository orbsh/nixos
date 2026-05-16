{
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
}
