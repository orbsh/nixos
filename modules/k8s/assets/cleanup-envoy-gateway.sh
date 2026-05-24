set -e
KUBECTL="$1"
echo "[cleanup-envoy-gateway] Cleaning up Envoy Gateway resources..."
$KUBECTL delete gateway -A --all --force --grace-period=0 2>/dev/null || true
$KUBECTL delete namespace envoy-gateway-system --force --grace-period=0 2>/dev/null || true
echo "[cleanup-envoy-gateway] Cleanup completed."
