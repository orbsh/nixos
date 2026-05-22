{ pkgs, lib, config, ... }: let
  kubeconfig = "/etc/kubernetes/cluster-admin.kubeconfig";
  kubectl = "${pkgs.kubectl}/bin/kubectl --kubeconfig ${kubeconfig}";
  istioctl = "${pkgs.istioctl}/bin/istioctl --kubeconfig ${kubeconfig}";

  assets = ./.;

  # IstioOperator 配置：包含所有 gateway 设置（含 TCP 端口）
  istioOperator = "${assets}/istio-operator.yaml";

  # 强制清理 Istio 资源（处理 finalizers 卡住问题）
  cleanupIstio = pkgs.writeShellScript "cleanup-istio.sh" (
    builtins.replaceStrings [ "@KUBECTL@" ] [ kubectl ]
      (builtins.readFile "${assets}/cleanup-istio.sh")
  );

  # Gateway API CRD 文件（experimental 通道，包含 TCPRoute/UDPRoute/GRPCRoute）
  gatewayApiCrdFile = pkgs.fetchurl {
    url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/experimental-install.yaml";
    hash = "sha256-VTMn4P8yoaK+RGv5OCPIQTz5JTrGptVAfuvR6NJp9p4=";
  };

  # Gateway 资源清单 (web + ssh/tcp + udp)
  gatewayManifest = "${assets}/istio-gateways.yaml";

in {
  config = {
    # ── Istio Gateway + Gateway API CRDs ─────────────────────
    # 使用 istioctl 部署 Istio（含 Gateway 配置）、Gateway API CRDs 和 Gateway 资源

    # ── Istio 安装（使用 IstioOperator）───────────────────────
    systemd.services.deploy-istio = {
      description = "Install Istio service mesh via IstioOperator";
      after = [ "kubelet.service" "kube-apiserver.service" ];
      wantedBy = lib.mkForce [];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "5min";
      };
      script = ''
        # 等待 API Server 就绪
        echo "[deploy-istio] Waiting for API server..."
        for i in $(seq 1 12); do
          if ${kubectl} cluster-info --request-timeout=5s >/dev/null 2>&1; then
            break
          fi
          echo "[deploy-istio] Attempt $i/12, retrying in 10s..."
          sleep 10
        done

        # 检查是否需要重新安装
        if ${kubectl} get namespace istio-system &>/dev/null; then
          echo "[deploy-istio] Detected existing Istio installation, reconciling with IstioOperator..."
          ${istioctl} install -y -f ${istioOperator}
        else
          echo "[deploy-istio] Installing Istio with IstioOperator..."
          ${istioctl} install -y -f ${istioOperator}
        fi
      '';
    };

    # ── 强制清理 Istio（手动触发）──────────────────────────
    # 用法：systemctl start cleanup-istio.service
    systemd.services.cleanup-istio = {
      description = "Force cleanup Istio resources (handles stuck finalizers)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = cleanupIstio;
      };
    };

    # ── Gateway API CRDs (experimental) ──────────────────────
    systemd.services.deploy-gateway-api-crds = {
      description = "Deploy Gateway API Experimental CRDs (includes TCPRoute/UDPRoute)";
      after = [ "deploy-istio.service" ];
      wantedBy = lib.mkForce [];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "2min";
      };
      script = ''
        echo "Deploying Gateway API Experimental CRDs..."
        # 使用 --server-side 避免客户端注解超过 256KB 限制
        # 详见: https://github.com/kubernetes-sigs/gateway-api/issues/4156
        ${kubectl} apply --server-side -f ${gatewayApiCrdFile}
      '';
    };

    # ── Set ExternalTrafficPolicy to Local ────────────────────
    systemd.services.set-external-traffic-policy = {
      description = "Set externalTrafficPolicy to Local on istio-ingressgateway";
      after = [ "deploy-istio.service" ];
      wantedBy = lib.mkForce [];
      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = 10;
        StartLimitIntervalSec = 300;
        StartLimitBurst = 10;
        TimeoutStartSec = "3min";
      };
      script = ''
        # 等待 istio-ingressgateway Service 就绪（最多 3 分钟）
        echo "[external-traffic-policy] Waiting for istio-ingressgateway Service..."
        for i in $(seq 1 18); do
          if ${kubectl} get svc istio-ingressgateway -n istio-system &>/dev/null; then
            echo "[external-traffic-policy] Service found."
            break
          fi
          echo "[external-traffic-policy] Attempt $i/18, retrying in 10s..."
          sleep 10
        done

        # 确认 Service 存在后再 patch
        if ${kubectl} get svc istio-ingressgateway -n istio-system &>/dev/null; then
          echo "[external-traffic-policy] Setting externalTrafficPolicy to Local..."
          ${kubectl} patch svc -n istio-system istio-ingressgateway \
            -p '{"spec":{"externalTrafficPolicy":"Local"}}'
        else
          echo "[external-traffic-policy] ERROR: Service not found after 3 minutes."
          exit 1
        fi
      '';
    };

    # ── Gateway 资源 (web + tcp + udp) ──────────────────────────────
    systemd.services.deploy-gateways = {
      description = "Deploy Gateway resources (web, tcp, udp)";
      after = [ "deploy-gateway-api-crds.service" ];
      wantedBy = lib.mkForce [];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "2min";
      };
      script = ''
        echo "Deploying Gateway resources..."
        ${kubectl} apply --server-side -f ${gatewayManifest}
      '';
    };

    # ── 重建完成后打印 Istio 服务启动命令 ────────────────────
    system.activationScripts.istio-reminder = {
      text = ''
        echo ""
        echo "=== Istio 部署服务启动命令 ==="
        echo ""
        echo "  sudo systemctl start deploy-istio.service deploy-gateway-api-crds.service deploy-gateways.service"
        echo ""
      '';
      deps = [];
    };
  };
}
