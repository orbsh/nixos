set -e
KUBECTL="@KUBECTL@"

echo "[cleanup-istio] Force-cleaning istio-system namespace..."

# 1. Remove Gateway resource finalizers (most common cause of stuck deletion)
echo "[cleanup-istio] Removing Gateway finalizers..."
for gw in $($KUBECTL get gateway -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null || true); do
  ns=$(echo $gw | cut -d/ -f1)
  name=$(echo $gw | cut -d/ -f2)
  $KUBECTL patch gateway $name -n $ns --type=json -p '[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true
done

# 2. Remove finalizers from all Istio-related CRD resources
echo "[cleanup-istio] Removing Istio CR finalizers..."
for crd in envoyfilter gateway grpcroute httproute referencegrant tcproute tlsservice udproute virtualservice wasmplugin; do
  for ns in $($KUBECTL get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null); do
    for item in $($KUBECTL get $crd -n $ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true); do
      $KUBECTL patch $crd $item -n $ns --type=json -p '[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true
    done
  done
done

# 3. Remove finalizers from all resources in istio-system namespace
echo "[cleanup-istio] Removing all istio-system resource finalizers..."
for resource in $($KUBECTL api-resources --verbs=list --namespaced -o name 2>/dev/null | head -30); do
  for item in $($KUBECTL get $resource -n istio-system -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true); do
    $KUBECTL patch $resource $item -n istio-system --type=json -p '[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true
  done
done

# 4. Force delete istio-system namespace
echo "[cleanup-istio] Deleting istio-system namespace..."
$KUBECTL delete namespace istio-system --grace-period=0 --force 2>/dev/null || true

# 5. Wait for namespace to be fully deleted (max 60 seconds)
echo "[cleanup-istio] Waiting for namespace to be deleted..."
for i in $(seq 1 12); do
  if ! $KUBECTL get namespace istio-system &>/dev/null; then
    echo "[cleanup-istio] istio-system deleted successfully."
    exit 0
  fi
  sleep 5
done

echo "[cleanup-istio] WARNING: istio-system still exists after 60s."
echo "[cleanup-istio] Manual intervention may be required:"
echo "[cleanup-istio]   kubectl get namespace istio-system -o json | jq '.spec.finalizers=[]' | kubectl replace --raw /api/v1/namespaces/istio-system/finalize -f -"
exit 1
