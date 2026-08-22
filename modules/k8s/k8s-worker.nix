{ pkgs, lib, ... }: {
  imports = [ ./k8s-common.nix ];

  # ── 工作节点角色 ───────────────────────────────────────
  # 设置角色为 node 启用 kubelet 和 kube-proxy
  services.kubernetes.roles = [ "node" ];

  # ── 防火墙：工作节点端口 ───────────────────────────────
  services.kubernetes.firewallPorts = [
    80 443      # Ingress/Service
    10256       # kube-proxy
  ];
}
