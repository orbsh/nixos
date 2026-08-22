#!/usr/bin/env bash
# Patch CoreDNS deployment 和 Corefile
#
# 变量 @KUBECTL@, @KUBECONFIG@, @IP@, @FORWARD_TARGET@ 由 Nix replaceStrings 注入
#
# 前提：cni0 网桥已存在（由 k8s-flannel-apply.service 创建）
#
# ── DNS 链路 ──────────────────────────────────────────────
# Pod 查询外部域名（如 smtp.exmail.qq.com）
#   ↓
# kube-dns ClusterIP (10.0.0.254)
#   ↓
# 集群内 CoreDNS pod（kube-system namespace）
#   ↓
# Corefile: forward . <目标>
#   ↓
# 目标 = 宿主机 CoreDNS（有）或 公共 DNS（无）
#
# ── 问题 ──────────────────────────────────────────────────
# CoreDNS pod 的 dnsPolicy 是 Default（使用宿主机 /etc/resolv.conf）
# 宿主机 /etc/resolv.conf 指向 127.0.0.1（NixOS 本地 stub resolver）
# 但 pod 内 127.0.0.1 是容器 loopback（无 DNS 服务）→ 转发失败
#
# ── 解决 ──────────────────────────────────────────────────
# 1. 给 CoreDNS pod 设置 KUBERNETES_SERVICE_HOST=<cni0IP>（让 kubernetes 插件能访问 API Server）
# 2. 改 Corefile 的 forward 目标：
#    - 宿主机有 CoreDNS：forward . <cni0IP>（直接指向宿主机 CoreDNS）
#    - 宿主机无 CoreDNS：forward . 223.5.5.5 119.29.29.29 1.1.1.1（公共 DNS）
# ──────────────────────────────────────────────────────────

# 获取 cni0 网桥 IP（单节点 K8s 的 API Server 和宿主机 CoreDNS 都通过此 IP 可达）
cni0IP=$(@IP@ -4 addr show cni0 2>/dev/null | grep -oP 'inet \K[\d.]+')
if [ -z "$cni0IP" ]; then
  echo "[coredns-patch] ERROR: Could not detect cni0 IP"
  exit 1
fi
echo "[coredns-patch] Using cni0 IP: $cni0IP"

# ── 1. Patch CoreDNS deployment：设置 KUBERNETES_SERVICE_HOST ──
# 让 CoreDNS 的 kubernetes 插件能通过 cni0 访问 API Server
@KUBECTL@ --kubeconfig=@KUBECONFIG@ patch deployment coredns -n kube-system \
  -p '{"spec":{"template":{"spec":{"$setElementOrder/containers":[{"name":"coredns"}],"containers":[{"name":"coredns","env":[{"name":"KUBERNETES_SERVICE_HOST","value":"'$cni0IP'"},{"name":"KUBERNETES_SERVICE_PORT","value":"6443"}]}]}}}}'

# ── 2. Patch CoreDNS Corefile：改 forward 目标 ──
# 默认是 `forward . /etc/resolv.conf`，但 pod 内 /etc/resolv.conf 指向 127.0.0.1（容器 loopback）
# 根据宿主机是否有 CoreDNS：
#   - 有：forward . <cni0IP>（宿主机 CoreDNS）
#   - 无：forward . 223.5.5.5 119.29.29.29 1.1.1.1（公共 DNS）
FORWARD_TARGET="@FORWARD_TARGET@"
# 如果 FORWARD_TARGET 是 @CNI0_IP@，则替换为实际的 cni0IP
if [ "$FORWARD_TARGET" = "@CNI0_IP@" ]; then
  FORWARD_TARGET="$cni0IP"
fi

COREFILE=$(cat <<EOF
.:10053 {
  errors
  health :10054
  kubernetes cluster.local in-addr.arpa ip6.arpa {
    pods insecure
    fallthrough in-addr.arpa ip6.arpa
  }
  prometheus :10055
  forward . $FORWARD_TARGET
  cache 30
  loop
  reload
  loadbalance
}
EOF
)

@KUBECTL@ --kubeconfig=@KUBECONFIG@ patch configmap coredns -n kube-system \
  --type merge -p "{\"data\":{\"Corefile\":$(printf '%s\n' "$COREFILE" | @JQ@ -Rs .)}}"
