{ pkgs, ... }: {
  imports = [
    ./k8s-common.nix
    ./k8s-addons.nix
    ./envoy-gateway.nix
    # ./istio-gateway.nix
    ./cert-manager.nix
  ];

  # ── 控制平面组件 ───────────────────────────────────────
  # 设置角色为 master 自动启用 apiserver、scheduler、controllerManager 等
  services.kubernetes.roles = [ "master" ];

  # etcd 由 roles = ["master"] 自动启用，但此处显式开启以确保
  services.etcd.enable = true;

  # ── 防火墙：控制平面端口 ───────────────────────────────
  networking.firewall.allowedTCPPorts = [
    80 443      # Ingress/Service
    2379 2380   # etcd
  ];
}
