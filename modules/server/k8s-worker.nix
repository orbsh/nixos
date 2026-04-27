{ ... }: {
  imports = [ ./k8s-common.nix ];

  # ── 工作节点组件 ───────────────────────────────────────
  # kubelet 已在 k8s-common 中启用
  # kube-proxy 由 k8s 模块自动管理

  # ── 防火墙：工作节点端口 ───────────────────────────────
  networking.firewall.allowedTCPPorts = [
    80 443      # Ingress/Service（若运行 NodePort/Ingress）
  ];
}