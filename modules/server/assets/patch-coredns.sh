#!/usr/bin/env bash
# Patch CoreDNS env to use cni0 bridge IP as KUBERNETES_SERVICE_HOST.
# Variables @KUBECTL@ and @KUBECONFIG@ are injected by Nix substituteAll.

# Wait for cni0 interface to appear (created by Flannel Pod startup)
echo "[coredns-patch] Waiting for cni0 interface..."
for i in $(seq 1 100); do
  if ip link show cni0 >/dev/null 2>&1; then
    echo "[coredns-patch] cni0 interface detected"
    break
  fi
  if [ "$i" -eq 100 ]; then
    echo "[coredns-patch] ERROR: cni0 interface not found after 300s"
    exit 1
  fi
  echo "[coredns-patch] Attempt $i/100, waiting for Flannel to create cni0..."
  sleep 3
done

# Get cni0 interface IP (API Server reachable via this on single-node)
apiServerIP=$(ip -4 addr show cni0 2>/dev/null | grep -oP 'inet \K[\d.]+')
if [ -z "$apiServerIP" ]; then
  echo "[coredns-patch] ERROR: Could not detect cni0 IP"
  exit 1
fi
echo "[coredns-patch] Using API server IP: $apiServerIP"

@KUBECTL@ --kubeconfig=@KUBECONFIG@ patch deployment coredns -n kube-system \
  -p '{"spec":{"template":{"spec":{"$setElementOrder/containers":[{"name":"coredns"}],"containers":[{"name":"coredns","env":[{"name":"KUBERNETES_SERVICE_HOST","value":"'$apiServerIP'"},{"name":"KUBERNETES_SERVICE_PORT","value":"6443"}]}]}}}}'
