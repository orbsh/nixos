# 容器镜像仓库配置（CRI-O/podman 和 containerd 通用）
{ lib, ... }: {
  # ── CRI-O / Podman（/etc/containers/registries.conf）────
  environment.etc."containers/registries.conf".text = lib.mkForce ''
    unqualified-search-registries = ["docker.io"]

    [[registry]]
    prefix = "registry.k8s.io"
    location = "registry.aliyuncs.com/google_containers"

    [[registry]]
    insecure = true
    location = "registry.s"

    [[registry]]
    insecure = true
    location = "registry.d"

    [[registry]]
    insecure = true
    location = "172.178.5.123:5000"

    [[registry]]
    insecure = true
    location = "localhost:5000"

    [[registry]]
    prefix = "docker.io"
    location = "docker.lizzie.fun"

    [[registry]]
    prefix = "ghcr.io"
    location = "ghcr.lizzie.fun"
  '';
}
