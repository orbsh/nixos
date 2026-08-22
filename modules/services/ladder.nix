{ ... }: {
  # mihomo 代理服务单元：引用 podman 内共享网络 + 自身 pod
  imports = [
    ./podman/network.nix
    ./podman/mihomo.nix
  ];
}
