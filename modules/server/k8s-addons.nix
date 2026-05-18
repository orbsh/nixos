# Kubernetes Addons（NixOS 声明式管理）
# 纯 Nix 生成 YAML manifest，替代运行时 kubectl patch
# 包含：Flannel CNI、CoreDNS env patch、RBAC 修复
{ pkgs, lib, config, ... }:
let
  cfg = config.services.kubernetes.addons;
  kubectl = "${pkgs.kubectl}/bin/kubectl";
  kubeconfig = "/etc/kubernetes/cluster-admin.kubeconfig";
  apiServerIP = config.services.kubernetes.masterAddress;
  podCIDR = config.services.kubernetes.podCIDR;

  # ── 构建时下载 Flannel manifest ────────────────────────────
  flannelVersion = "0.28.4";
  flannelManifest = pkgs.fetchurl {
    url = "https://github.com/flannel-io/flannel/releases/download/v${flannelVersion}/kube-flannel.yml";
    hash = "sha256-0HgBl0PF4BlM6WUSX8gO8ArwwWYeyeEjljEfHP7IYKI=";
  };

  # ── 生成 CoreDNS env patch YAML ────────────────────────────
  corednsPatchYaml = pkgs.writeText "coredns-env-patch.yaml" ''
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: coredns
      namespace: kube-system
    spec:
      template:
        spec:
          containers:
          - name: coredns
            env:
            - name: KUBERNETES_SERVICE_HOST
              value: "${apiServerIP}"
            - name: KUBERNETES_SERVICE_PORT
              value: "6443"
  '';

  # ── 生成 Flannel CIDR patch YAML ───────────────────────────
  flannelCIDRYaml = pkgs.writeText "flannel-cidr-patch.yaml" ''
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: kube-flannel-cfg
      namespace: kube-flannel
    data:
      net-conf.json: |
        {
          "Network": "${podCIDR}",
          "EnableNFTables": false,
          "Backend": {
            "Type": "vxlan"
          }
        }
  '';

  # ── 完整部署脚本（带重试机制） ──────────────────────────
  deployScript = pkgs.writeShellScript "k8s-addons-deploy.sh" ''
    set -euo pipefail

    KUBECTL="${kubectl} --kubeconfig=${kubeconfig}"
    MAX_RETRIES=12
    RETRY_INTERVAL=10

    # 等待 API Server 就绪
    echo "[k8s-addons] Waiting for API server..."
    for i in $(seq 1 $MAX_RETRIES); do
      if $KUBECTL cluster-info --request-timeout=5s >/dev/null 2>&1; then
        echo "[k8s-addons] API server is ready."
        break
      fi
      if [ $i -eq $MAX_RETRIES ]; then
        echo "[k8s-addons] ERROR: API server not ready after $((MAX_RETRIES * RETRY_INTERVAL))s."
        echo "[k8s-addons] Service will retry on next activation."
        exit 1
      fi
      echo "[k8s-addons] Attempt $i/$MAX_RETRIES, retrying in ${RETRY_INTERVAL}s..."
      sleep $RETRY_INTERVAL
    done

    echo "[k8s-addons] Starting addon deployment..."

    # 1. 删除 NixOS k8s 模块自动创建的 User 类型 RBAC binding
    echo "[k8s-addons] Removing conflicting flannel ClusterRoleBinding..."
    $KUBECTL delete clusterrolebinding flannel --ignore-not-found=true --wait 2>/dev/null || true

    # 2. 删除旧 Flannel DaemonSet（selector 不可变，必须先删后建）
    echo "[k8s-addons] Removing old Flannel DaemonSet..."
    $KUBECTL delete daemonset kube-flannel-ds -n kube-flannel --ignore-not-found=true --wait 2>/dev/null || true

    # 3. Apply Flannel 官方 manifest
    echo "[k8s-addons] Applying Flannel manifest (v${flannelVersion})..."
    $KUBECTL apply -f ${flannelManifest} --server-side --force-conflicts 2>/dev/null || {
      echo "[k8s-addons] WARN: Flannel apply failed, will retry on next activation."
      exit 1
    }

    # 4. Patch Flannel CIDR 为配置的 Pod 网段
    echo "[k8s-addons] Patching Flannel CIDR to ${podCIDR}..."
    $KUBECTL apply -f ${flannelCIDRYaml} 2>/dev/null || {
      echo "[k8s-addons] WARN: Flannel CIDR patch failed, will retry on next activation."
      exit 1
    }

    # 5. Apply CoreDNS env patch
    echo "[k8s-addons] Patching CoreDNS with API server address..."
    $KUBECTL apply -f ${corednsPatchYaml} 2>/dev/null || {
      echo "[k8s-addons] WARN: CoreDNS patch failed, will retry on next activation."
      exit 1
    }

    # 6. 重启受影响的 Pod 使其读取新配置
    echo "[k8s-addons] Restarting affected pods..."
    $KUBECTL delete pod -n kube-flannel -l app=flannel --ignore-not-found=true --wait 2>/dev/null || true
    $KUBECTL rollout restart deployment coredns -n kube-system --wait 2>/dev/null || true

    echo "[k8s-addons] Addon deployment complete."
  '';
in {
  # ── 声明式选项 ──────────────────────────────────────────
  options.services.kubernetes.addons = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable K8s addon management (Flannel, CoreDNS patch, etc.)";
    };
  };

  # ── 系统配置 ────────────────────────────────────────────
  config = lib.mkIf cfg.enable {
    # CNI 插件：仅包含 cni-plugins，排除 cni-plugin-flannel
    # （避免 NixOS 自动生成 11-flannel.conf 创建多余的 mynet 网桥）
    services.kubernetes.kubelet.cni.packages =
      lib.mkForce [ pkgs.cni-plugins ];

    # ── Addon 部署服务 ────────────────────────────────────
    systemd.services.k8s-addons-apply = {
      description = "Apply K8s addon manifests (NixOS-managed)";
      wantedBy = [ "multi-user.target" ];
      after = [ "kubelet.service" "kube-apiserver.service" ];
      wants = [ "kube-addon-manager.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = deployScript;
        TimeoutStartSec = "10min";
      };
    };
  };
}
