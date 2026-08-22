#!/usr/bin/env bash
# Generate inline kubeconfig file
# Usage: generate-kubeconfig.sh [output_path] [cluster_name] [apiserver_url]
# Defaults:
#   output_path: ~/.kube/config
#   cluster_name: kubernetes
#   apiserver: https://172.178.5.123:6443 (read from current node)
#
set -euo pipefail

SECRETS_DIR="/var/lib/kubernetes/secrets"
OUTPUT_PATH="${1:-$HOME/.kube/config}"
CLUSTER_NAME="${2:-kubernetes}"

# Read API Server address from kubernetes config if not provided as 3rd arg
if [ $# -ge 3 ]; then
    APISERVER="$3"
else
    # Try to read from running kube-apiserver, or use default
    APISERVER="https://localhost:6443"
fi

# Check if certificate files exist
if [ ! -f "$SECRETS_DIR/cluster-admin.pem" ] || [ ! -f "$SECRETS_DIR/cluster-admin-key.pem" ]; then
    echo "Error: certificate files not found, please ensure Kubernetes is properly initialized"
    exit 1
fi

# Create output directory
mkdir -p "$(dirname "$OUTPUT_PATH")"

# Read certificates and private key
CA_CERT=$(cat "$SECRETS_DIR/ca.pem")
CLIENT_CERT=$(cat "$SECRETS_DIR/cluster-admin.pem")
CLIENT_KEY=$(cat "$SECRETS_DIR/cluster-admin-key.pem")

# Generate kubeconfig
cat > "$OUTPUT_PATH" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $(echo "$CA_CERT" | base64 -w 0)
    server: $APISERVER
  name: $CLUSTER_NAME
contexts:
- context:
    cluster: $CLUSTER_NAME
    user: cluster-admin
  name: $CLUSTER_NAME
current-context: $CLUSTER_NAME
users:
- name: cluster-admin
  user:
    client-certificate-data: $(echo "$CLIENT_CERT" | base64 -w 0)
    client-key-data: $(echo "$CLIENT_KEY" | base64 -w 0)
EOF

# Set permissions (readable/writable by owner only)
chmod 600 "$OUTPUT_PATH"

echo "kubeconfig generated: $OUTPUT_PATH"
echo "  Cluster name: $CLUSTER_NAME"
echo "  API Server: $APISERVER"
echo "WARNING: This file contains private keys, keep it secure"
echo "  - Do not commit to git"
echo "  - Do not upload to public locations"
echo "  - Delete manually after use: rm $OUTPUT_PATH"
