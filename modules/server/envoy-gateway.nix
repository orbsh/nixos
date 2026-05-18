# modules/server/envoy-gateway.nix
# Envoy Gateway 配置模块（基于 Gateway API）
# 注意：此模块与 istio-gateway.nix 互斥，切换时需替换 imports
{ pkgs, lib, config, ... }: let
  kubeconfig = "/etc/kubernetes/cluster-admin.kubeconfig";
  kubectl = "${pkgs.kubectl}/bin/kubectl --kubeconfig ${kubeconfig}";

  # Gateway API CRD 文件 (experimental)
  gatewayApiCrdFile = pkgs.fetchurl {
    url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/experimental-install.yaml";
    hash = "sha256-VTMn4P8yoaK+RGv5OCPIQTz5JTrGptVAfuvR6NJp9p4=";
  };

  # Envoy Gateway 安装文件 (v1.2.1)
    # 首次使用需运行: nix-prefetch-url https://github.com/envoyproxy/gateway/releases/download/v1.2.1/install.yaml
    envoyGatewayRawFile = pkgs.fetchurl {
      url = "https://github.com/envoyproxy/gateway/releases/download/v1.2.1/install.yaml";
      hash = "sha256-SleqK41bGrI1KNd9qGlQjSSnxiGqkRhO0yGfWaJ83cs=";
    };

    # 过滤掉 Gateway API CRD（已由 deploy-gateway-api-crds-eg 部署），避免版本冲突
    envoyGatewayInstallFile = pkgs.runCommand "envoy-gateway-filtered.yaml" {
      src = envoyGatewayRawFile;
    }
    ''
      # 使用 yq-go 过滤掉 Gateway API CRD（group 为 gateway.networking.k8s.io）
      ${pkgs.yq-go}/bin/yq eval-all '
        select(
          .kind != "CustomResourceDefinition" or
          .spec.group != "gateway.networking.k8s.io"
        )
      ' $src > $out
    '';

  # Envoy Gateway 资源清单 (GatewayClass + Gateway)
  envoyGatewayManifest = pkgs.writeText "envoy-gateways.yaml" ''
    apiVersion: gateway.networking.k8s.io/v1
    kind: GatewayClass
    metadata:
      name: envoy
    spec:
      controllerName: gateway.envoyproxy.io/gatewayclass-controller
    ---
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: web
      namespace: envoy-gateway-system
    spec:
      gatewayClassName: envoy
      listeners:
      - name: http
        port: 80
        protocol: HTTP
        allowedRoutes:
          namespaces:
            from: All
      - name: https
        port: 443
        protocol: HTTPS
        allowedRoutes:
          namespaces:
            from: All
        tls:
          mode: Terminate
          certificateRefs:
            - name: cert-web
              kind: Secret
              group: core
    ---
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: tcp
      namespace: envoy-gateway-system
    spec:
      gatewayClassName: envoy
      listeners:
      - name: tcp-ssh
        port: 22
        protocol: TCP
        allowedRoutes:
          namespaces:
            from: All
    ---
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: udp
      namespace: envoy-gateway-system
    spec:
      gatewayClassName: envoy
      listeners:
      - name: udp-dns
        port: 53
        protocol: UDP
        allowedRoutes:
          namespaces:
            from: All
  '';

  # 清理脚本
  cleanupEnvoyGateway = pkgs.writeShellScript "cleanup-envoy-gateway.sh" ''
    set -e
    KUBECTL="${kubectl}"
    echo "[cleanup-envoy-gateway] Cleaning up Envoy Gateway resources..."
    $KUBECTL delete gateway -A --all --force --grace-period=0 2>/dev/null || true
    $KUBECTL delete namespace envoy-gateway-system --force --grace-period=0 2>/dev/null || true
    echo "[cleanup-envoy-gateway] Cleanup completed."
  '';

in {
  config = {
    # ── Gateway API CRDs ──────────────────────────────
    systemd.services.deploy-gateway-api-crds-eg = {
      description = "Deploy Gateway API Experimental CRDs for Envoy Gateway";
      after = [ "kube-apiserver.service" ];
      wantedBy = lib.mkForce [];
      serviceConfig.Type = "oneshot";
      script = ''
        echo "Deploying Gateway API CRDs..."
        # 使用 --server-side 避免客户端注解超过 256KB 限制
        # 详见: https://github.com/kubernetes-sigs/gateway-api/issues/4156
        ${kubectl} apply --server-side -f ${gatewayApiCrdFile}
      '';
    };

    # ── Envoy Gateway 安装 ──────────────────────────────
    systemd.services.deploy-envoy-gateway = {
      description = "Install Envoy Gateway";
      after = [ "deploy-gateway-api-crds-eg.service" "kube-apiserver.service" ];
      wantedBy = lib.mkForce [];
      serviceConfig.Type = "oneshot";
      script = ''
        echo "[deploy-envoy-gateway] Installing Envoy Gateway..."
        # Gateway API CRD 已在 deploy-gateway-api-crds-eg 中部署
        # 此处仅部署 Envoy Gateway 自身的 CRD 和其他资源
        ${kubectl} apply --server-side --force-conflicts -f ${envoyGatewayInstallFile}
      '';
    };

    # ── 部署 Gateway 资源 ──────────────────────────────
    systemd.services.deploy-envoy-gateways = {
      description = "Deploy Envoy Gateway resources (web, tcp, udp)";
      after = [ "deploy-envoy-gateway.service" ];
      wantedBy = lib.mkForce [];
      serviceConfig.Type = "oneshot";
      script = ''
        echo "[deploy-envoy-gateways] Deploying Gateway resources..."
        ${kubectl} apply --server-side -f ${envoyGatewayManifest}
      '';
    };

    # ── 清理 Envoy Gateway ──────────────────────────────
    systemd.services.cleanup-envoy-gateway = {
      description = "Cleanup Envoy Gateway resources";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = cleanupEnvoyGateway;
      };
    };

    # ── 重建完成后打印 Envoy Gateway 服务启动命令 ─────────
    system.activationScripts.envoy-gateway-reminder = {
      text = ''
        echo ""
        echo "=== Envoy Gateway 部署服务启动命令 ==="
        echo ""
        echo "  sudo systemctl start deploy-gateway-api-crds-eg.service deploy-envoy-gateway.service deploy-envoy-gateways.service"
        echo ""
      '';
      deps = [];
    };
  };
}
