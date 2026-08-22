# gitea 服务单元（自包含：app-net 共享网络 + gitea pod）
# 引用 podman/ 内多个基础设施，与 ladder 同层同构；network.nix 幂等，多服务共享 app-net。
{ ... }: {
  imports = [
    ./podman/network.nix
    ./podman/gitea.nix
  ];
}