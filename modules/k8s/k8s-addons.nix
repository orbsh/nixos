# Kubernetes Addons（NixOS 声明式管理）
# 纯 Nix 生成 YAML manifest，替代运行时 kubectl patch
# 拆分成三个独立服务：Flannel CNI、CoreDNS patch、metrics-server
{ pkgs, lib, config, publicDnsServers, ... }:
let
  cfg = config.services.kubernetes.addons;
  kubectl = "${pkgs.kubectl}/bin/kubectl";
  ip = "${pkgs.iproute2}/bin/ip";
  jq = "${pkgs.jq}/bin/jq";
  kubeconfig = "/etc/kubernetes/cluster-admin.kubeconfig";
  apiServerIP = config.services.kubernetes.masterAddress;
  podCIDR = config.services.kubernetes.podCIDR;
  # 公共 DNS 字符串（用于 shell 脚本）
  publicDnsServersStr = lib.concatStringsSep " " publicDnsServers;

  assets = ./assets;

  # ── 构建时下载 Flannel manifest ────────────────────────────
  # 本地管理，避免构建时依赖网络（使用 assets/ 目录下的静态文件）
  flannelVersion = "0.28.4";
  flannelManifest = ./assets/flannel-v0.28.4.yml;

  # ── metrics-server（纯静态清单） ──────────────────────────
  metricsServerPatched = "${assets}/metrics-server.yaml";

  # ── Flannel CIDR patch（含 @POD_CIDR@ 占位符） ───────────
  flannelCIDRYaml = pkgs.writeText "flannel-cidr-patch.yaml" (
    builtins.replaceStrings [ "@POD_CIDR@" ] [ podCIDR ]
      (builtins.readFile "${assets}/flannel-cidr-patch.yaml")
  );

  # ── CoreDNS env patch 脚本（含 @KUBECTL@ / @KUBECONFIG@ / @IP@ / @FORWARD_TARGET@ 占位符）─
  # 根据宿主机是否有 CoreDNS，生成不同的 forward 目标
  forwardTarget =
    if config.services.coredns.enable or false
    then "@CNI0_IP@"  # 占位符，运行时替换为 cni0IP
    else publicDnsServersStr;  # 公共 DNS
  patchCoreDNSScript = pkgs.writeShellScript "patch-coredns.sh" (
    builtins.replaceStrings [ "@KUBECTL@" "@KUBECONFIG@" "@IP@" "@JQ@" "@FORWARD_TARGET@" ] [ kubectl kubeconfig ip jq forwardTarget ]
      (builtins.readFile "${assets}/patch-coredns.sh")
  );

  # ── Flannel CNI 部署脚本 ──────────────────────────────────
  flannelDeployScript = pkgs.writeShellScript "k8s-flannel-deploy.sh" ''
    set -uo pipefail

    KUBECTL="${kubectl} --kubeconfig=${kubeconfig}"
    MAX_RETRIES=12
    RETRY_INTERVAL=10

    # 等待 API Server 就绪
    echo "[k8s-flannel] Waiting for API server..."
    for i in $(seq 1 $MAX_RETRIES); do
      if $KUBECTL cluster-info --request-timeout=5s >/dev/null 2>&1; then
        echo "[k8s-flannel] API server is ready."
        break
      fi
      if [ $i -eq $MAX_RETRIES ]; then
        echo "[k8s-flannel] ERROR: API server not ready after $((MAX_RETRIES * RETRY_INTERVAL))s."
        exit 1
      fi
      echo "[k8s-flannel] Attempt $i/$MAX_RETRIES, retrying in ''${RETRY_INTERVAL}s..."
      sleep $RETRY_INTERVAL
    done

    echo "[k8s-flannel] Starting Flannel deployment..."

    # 0. 清理 NixOS flannel 残留（旧系统激活后可能仍存在）
    echo "[k8s-flannel] Cleaning up stale NixOS flannel artifacts..."
    ${ip} link delete mynet 2>/dev/null && echo "[k8s-flannel] Deleted mynet bridge" || echo "[k8s-flannel] mynet not found (already clean)"

    # 1. 删除 NixOS k8s 模块自动创建的 User 类型 RBAC binding
    echo "[k8s-flannel] Removing conflicting flannel ClusterRoleBinding..."
    $KUBECTL delete clusterrolebinding flannel --ignore-not-found=true --wait 2>/dev/null || true

    # 2. 删除旧 Flannel DaemonSet（selector 不可变，必须先删后建）
    echo "[k8s-flannel] Removing old Flannel DaemonSet..."
    $KUBECTL delete daemonset kube-flannel-ds -n kube-flannel --ignore-not-found=true --wait 2>/dev/null || true

    # 3. Apply Flannel 官方 manifest
    echo "[k8s-flannel] Applying Flannel manifest (v${flannelVersion})..."
    if ! $KUBECTL apply -f ${flannelManifest} --server-side --force-conflicts; then
      echo "[k8s-flannel] ERROR: Flannel apply failed"
      exit 1
    fi

    # 4. Patch Flannel CIDR 为配置的 Pod 网段
    echo "[k8s-flannel] Patching Flannel CIDR to ${podCIDR}..."
    if ! $KUBECTL patch configmap kube-flannel-cfg -n kube-flannel --type=merge --patch-file=${flannelCIDRYaml}; then
      echo "[k8s-flannel] ERROR: Flannel CIDR patch failed"
      exit 1
    fi

    # 5. 等待 Flannel Pod 就绪
    echo "[k8s-flannel] Waiting for Flannel DaemonSet to be ready..."
    if ! $KUBECTL rollout status daemonset kube-flannel-ds -n kube-flannel --timeout=180s; then
      echo "[k8s-flannel] ERROR: Flannel DaemonSet not ready within 180s"
      exit 1
    fi
    echo "[k8s-flannel] Flannel DaemonSet is ready"

    # 6. 触发 cni0 创建：删除现有 CoreDNS Pod，让 kubelet 用 Flannel CNI 重新调度
    echo "[k8s-flannel] Triggering cni0 creation by restarting CoreDNS..."
    $KUBECTL delete pod -n kube-system -l k8s-app=kube-dns --wait 2>/dev/null || true
    sleep 10

    # 7. 等待 cni0 接口出现
    echo "[k8s-flannel] Waiting for cni0 interface..."
    for i in $(seq 1 100); do
      if ${ip} link show cni0 >/dev/null 2>&1; then
        echo "[k8s-flannel] cni0 interface detected"
        exit 0
      fi
      if [ "$i" -eq 100 ]; then
        echo "[k8s-flannel] ERROR: cni0 interface not found after 300s"
        exit 1
      fi
      echo "[k8s-flannel] Attempt $i/100, waiting..."
      sleep 3
    done
  '';

  # ── CoreDNS patch 脚本 ────────────────────────────────────
  corednsPatchScript = pkgs.writeShellScript "k8s-coredns-patch.sh" ''
    set -uo pipefail

    KUBECTL="${kubectl} --kubeconfig=${kubeconfig}"

    echo "[k8s-coredns] Patching CoreDNS with API server address..."
    if ! ${patchCoreDNSScript}; then
      echo "[k8s-coredns] ERROR: CoreDNS patch failed"
      exit 1
    fi

    echo "[k8s-coredns] Restarting CoreDNS to apply env patch..."
    $KUBECTL rollout restart deployment coredns -n kube-system --wait 2>/dev/null || true

    echo "[k8s-coredns] CoreDNS patch complete."
  '';

  # ── metrics-server 部署脚本 ───────────────────────────────
  metricsServerScript = pkgs.writeShellScript "k8s-metrics-server-deploy.sh" ''
    set -uo pipefail

    KUBECTL="${kubectl} --kubeconfig=${kubeconfig}"

    echo "[k8s-metrics-server] Deploying metrics-server..."
    if ! $KUBECTL apply -f ${metricsServerPatched} --server-side --force-conflicts; then
      echo "[k8s-metrics-server] ERROR: metrics-server apply failed"
      exit 1
    fi
    echo "[k8s-metrics-server] metrics-server deployed"
  '';
in {
  # ── 声明式选项 ──────────────────────────────────────────
  options.services.kubernetes.addons = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable K8s addon management (Flannel, CoreDNS patch, metrics-server)";
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
        echo "  sudo systemctl start k8s-flannel-apply.service"
        echo "  sudo systemctl start k8s-coredns-patch.service"
        echo "  sudo systemctl start k8s-metrics-server-apply.service"
        echo ""
      '';
      deps = [];
    };

    # CNI 插件：包含标准插件 + flannel 二进制
    services.kubernetes.kubelet.cni.packages =
      lib.mkForce [ pkgs.cni-plugins pkgs.cni-plugin-flannel ];

    # 清除 kubelet 默认 CNI config
    services.kubernetes.kubelet.cni.config = lib.mkForce [];

    # 声明式创建 Flannel CNI 配置（替代 DaemonSet 运行时写入）
    environment.etc."cni/net.d" = lib.mkForce {
      source = pkgs.writeTextDir "10-flannel.conflist" ''
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
    };

    # ── Flannel CNI 部署服务 ────────────────────────────────
    systemd.services.k8s-flannel-apply = {
      description = "Deploy Flannel CNI (NixOS-managed)";
      wantedBy = lib.mkForce [];
      after = [ "kubelet.service" "kube-apiserver.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = flannelDeployScript;
        TimeoutStartSec = "10min";
      };
    };

    # ── CoreDNS patch 服务 ──────────────────────────────────
    systemd.services.k8s-coredns-patch = {
      description = "Patch CoreDNS with API server address (NixOS-managed)";
      wantedBy = lib.mkForce [];
      after = [ "k8s-flannel-apply.service" ];
      requires = [ "k8s-flannel-apply.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = corednsPatchScript;
        TimeoutStartSec = "5min";
      };
    };

    # ── metrics-server 部署服务 ─────────────────────────────
    systemd.services.k8s-metrics-server-apply = {
      description = "Deploy metrics-server (NixOS-managed)";
      wantedBy = lib.mkForce [];
      after = [ "kubelet.service" "kube-apiserver.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = metricsServerScript;
        TimeoutStartSec = "5min";
      };
    };
  };
}
