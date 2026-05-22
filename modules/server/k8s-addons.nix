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

  assets = ./.;

  # ── 构建时下载 Flannel manifest ────────────────────────────
  flannelVersion = "0.28.4";
  flannelManifest = pkgs.fetchurl {
    url = "https://github.com/flannel-io/flannel/releases/download/v${flannelVersion}/kube-flannel.yml";
    hash = "sha256-0HgBl0PF4BlM6WUSX8gO8ArwwWYeyeEjljEfHP7IYKI=";
  };

  # ── metrics-server（纯静态清单） ──────────────────────────
  metricsServerPatched = "${assets}/metrics-server.yaml";

  # ── Flannel CIDR patch（含 @POD_CIDR@ 占位符） ───────────
  flannelCIDRYaml = pkgs.writeText "flannel-cidr-patch.yaml" (
    builtins.replaceStrings [ "@POD_CIDR@" ] [ podCIDR ]
      (builtins.readFile "${assets}/flannel-cidr-patch.yaml")
  );

  # ── CoreDNS env patch 脚本（含 @KUBECTL@ / @KUBECONFIG@ 占位符）─
  patchCoreDNSScript = pkgs.writeShellScript "patch-coredns.sh" (
    builtins.replaceStrings [ "@KUBECTL@" "@KUBECONFIG@" ] [ kubectl kubeconfig ]
      (builtins.readFile "${assets}/patch-coredns.sh")
  );

  # ── 完整部署脚本（带重试机制） ──────────────────────────
  deployScript = pkgs.writeShellScript "k8s-addons-deploy.sh" ''
    set -uo pipefail

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
      echo "[k8s-addons] Attempt $i/$MAX_RETRIES, retrying in ''${RETRY_INTERVAL}s..."
      sleep $RETRY_INTERVAL
    done

    echo "[k8s-addons] Starting addon deployment..."

    # 0. 清理 NixOS flannel 残留（旧系统激活后可能仍存在）
    echo "[k8s-addons] Cleaning up stale NixOS flannel artifacts..."
    ip link delete mynet 2>/dev/null && echo "[k8s-addons] Deleted mynet bridge" || echo "[k8s-addons] mynet not found (already clean)"
    # 注意：/etc/cni/net.d/11-flannel.conf 是 NixOS 只读挂载，无法运行时删除
    # 必须通过 nixos-rebuild 激活新配置（flannel.enable=false）来移除

    # 1. 删除 NixOS k8s 模块自动创建的 User 类型 RBAC binding
    echo "[k8s-addons] Removing conflicting flannel ClusterRoleBinding..."
    $KUBECTL delete clusterrolebinding flannel --ignore-not-found=true --wait 2>/dev/null || true

    # 2. 删除旧 Flannel DaemonSet（selector 不可变，必须先删后建）
    echo "[k8s-addons] Removing old Flannel DaemonSet..."
    $KUBECTL delete daemonset kube-flannel-ds -n kube-flannel --ignore-not-found=true --wait 2>/dev/null || true

    # 3. Apply Flannel 官方 manifest
    echo "[k8s-addons] Applying Flannel manifest (v${flannelVersion})..."
    if ! $KUBECTL apply -f ${flannelManifest} --server-side --force-conflicts; then
      echo "[k8s-addons] ERROR: Flannel apply failed"
      exit 1
    fi

    # 4. Patch Flannel CIDR 为配置的 Pod 网段（使用 merge patch 保留 cni-conf.json）
    echo "[k8s-addons] Patching Flannel CIDR to ${podCIDR}..."
    if ! $KUBECTL patch configmap kube-flannel-cfg -n kube-flannel --type=merge --patch-file=${flannelCIDRYaml}; then
      echo "[k8s-addons] ERROR: Flannel CIDR patch failed"
      exit 1
    fi

    # 4.5. 等待 Flannel Pod 就绪
    echo "[k8s-addons] Waiting for Flannel DaemonSet to be ready..."
    if ! $KUBECTL rollout status daemonset kube-flannel-ds -n kube-flannel --timeout=120s; then
      echo "[k8s-addons] WARN: Flannel DaemonSet not ready within 120s, will retry on next activation"
      exit 1
    fi
    echo "[k8s-addons] Flannel DaemonSet is ready"

    # 4.6. 触发 cni0 创建：删除现有 CoreDNS Pod，让 kubelet 用 Flannel CNI 重新调度
    echo "[k8s-addons] Triggering cni0 creation by restarting CoreDNS..."
    $KUBECTL delete pod -n kube-system -l k8s-app=kube-dns --wait 2>/dev/null || true
    # 等待 kubelet 调度新 Pod 并创建 cni0（需要较长时间）
    sleep 15

    # 5. Patch CoreDNS env（使用 kubectl patch 而非 apply）
    echo "[k8s-addons] Patching CoreDNS with API server address..."
    if ! ${patchCoreDNSScript}; then
      echo "[k8s-addons] ERROR: CoreDNS patch failed"
      exit 1
    fi

    # 6. 再次重启 CoreDNS 使其使用新的 KUBERNETES_SERVICE_HOST 配置
    echo "[k8s-addons] Restarting CoreDNS to apply env patch..."
    $KUBECTL rollout restart deployment coredns -n kube-system --wait 2>/dev/null || true

    echo "[k8s-addons] Addon deployment complete."

    # 7. Deploy metrics-server for `kubectl top`
    echo "[k8s-addons] Deploying metrics-server..."
    if ! $KUBECTL apply -f ${metricsServerPatched} --server-side --force-conflicts; then
      echo "[k8s-addons] ERROR: metrics-server apply failed"
      exit 1
    fi
    echo "[k8s-addons] metrics-server deployed"
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
    # 重建完成后打印 K8s 部署服务启动命令
    system.activationScripts.k8s-addons-reminder = {
      text = ''
        echo ""
        echo "=== K8s Addons 部署服务启动命令 ==="
        echo ""
        echo "  sudo systemctl start k8s-addons-apply.service"
        echo ""
      '';
      deps = [];
    };

    # CNI 插件：包含标准插件 + flannel 二进制
    services.kubernetes.kubelet.cni.packages =
      lib.mkForce [ pkgs.cni-plugins pkgs.cni-plugin-flannel ];

    # 声明式创建 Flannel CNI 配置（替代 DaemonSet 运行时写入）
    environment.etc."cni/net.d/10-flannel.conflist".text = ''
      {
        "name": "cbr0",
        "cniVersion": "1.0.0",
        "plugins": [
          {
            "type": "flannel",
            "delegate": {
              "hairpinMode": true,
              "isDefaultGateway": true
            }
          },
          {
            "type": "portmap",
            "capabilities": {
              "portMappings": true
            }
          }
        ]
      }
    '';

    # ── Addon 部署服务 ────────────────────────────────────
    systemd.services.k8s-addons-apply = {
      description = "Apply K8s addon manifests (NixOS-managed)";
      wantedBy = lib.mkForce [];
      after = [ "kubelet.service" "kube-apiserver.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = deployScript;
        TimeoutStartSec = "10min";
      };
    };
  };
}
