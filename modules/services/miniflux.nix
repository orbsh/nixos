# miniflux 服务单元（自包含：app-net 共享网络 + miniflux pod）
# 引用 podman/ 内多个基础设施，与 ladder 同层同构。
{ ... }: {
  imports = [
    ./podman/network.nix
    ./podman/miniflux.nix
  ];
}