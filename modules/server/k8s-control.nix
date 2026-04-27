{ pkgs, ... }: {
  imports = [ ./k8s-common.nix ];

  # ── 控制平面组件 ───────────────────────────────────────
  services.kubernetes = {
    master.enable = true;       # apiserver + controller-manager + scheduler
    etcd.enable = true;         # 分布式存储
  };

  # ── kube-apiserver: NodePort 范围扩展 ─────────────────
  services.kubernetes.apiserver.extraOptions = [
    "--service-node-port-range=1-32767"
  ];

  # ── 防火墙：控制平面端口 ───────────────────────────────
  networking.firewall.allowedTCPPorts = [
    80 443      # Ingress/Service
    2379 2380   # etcd
  ];
}