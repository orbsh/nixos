# modules/server/envoy-gateway.nix
# Envoy Gateway 配置模块（基于 Gateway API）
# 注意：此模块与 istio-gateway.nix 互斥，切换时需替换 imports
{ pkgs, lib, config, ... }: let
  kubeconfig = "/etc/kubernetes/cluster-admin.kubeconfig";
  kubectl = "${pkgs.kubectl}/bin/kubectl --kubeconfig ${kubeconfig}";

  # Gateway API CRD 文件 (experimental)
  gatewayApiCrdFile = pkgs.fetchurl {
    url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/experimental-install.yaml";
    hash = "sha256-98x9MJp62dMWk4NBBG7YHEDnh9gILwsoHfOSYomnpEU=";
  };

  # Envoy Gateway 安装文件 (v1.8.0)
    # 首次使用需运行: nix-prefetch-url https://github.com/envoyproxy/gateway/releases/download/v1.8.0/install.yaml
    envoyGatewayRawFile = pkgs.fetchurl {
      url = "https://github.com/envoyproxy/gateway/releases/download/v1.8.0/install.yaml";
      hash = "sha256-nKa3I+6idxzYBuWuQ3K6lBsVjgIFM1UBc2qkyIavckg=";
    };

    # 过滤掉 Gateway API CRD（已由 deploy-gateway-api-crds-eg 部署），避免版本冲突
    envoyGatewayInstallFile = pkgs.runCommand "envoy-gateway-filtered.yaml" {
      src = envoyGatewayRawFile;
    }
    ''
      # 1. 使用 sed 为 envoyproxy/gateway 镜像添加私有仓库前缀
      # 2. 使用 yq-go 过滤掉 Gateway API CRD（group 为 gateway.networking.k8s.io）
      sed 's|envoyproxy/gateway:|docker.lizzie.fun/envoyproxy/gateway:|g' $src |
      ${pkgs.yq-go}/bin/yq eval-all '
        select(
          .kind != "CustomResourceDefinition" or
          .spec.group != "gateway.networking.k8s.io"
        )
      ' > $out
    '';

  # Kubernetes Reflector manifest for cross-namespace Secret sync
  # Patched to use docker.lizzie.fun mirror and add a metrics Service
  reflectorManifest = pkgs.runCommand "reflector-patched.yaml" {
    raw = pkgs.fetchurl {
      url = "https://github.com/emberstack/kubernetes-reflector/releases/latest/download/reflector.yaml";
      hash = "sha256-SwcNk/ovfQqiS7pqHrIi+DndcFSulYQI2i+wqPvZ8R0=";
    };
  } ''
    sed 's|docker.io/emberstack/|docker.lizzie.fun/emberstack/|g' $raw > $out
    cat >> $out << 'EOF'
---
apiVersion: v1
kind: Service
metadata:
  name: reflector-metrics
  namespace: kube-system
  labels:
    app.kubernetes.io/name: reflector
spec:
  ports:
    - name: metrics
      port: 8080
      targetPort: http
      protocol: TCP
  selector:
    app.kubernetes.io/name: reflector
EOF
  '';

  # Generate YAML snippet for certificateRefs from option
  certRefsYaml = ''
            - name: tls-envoy-gateway
              kind: Secret
              group: ""
  '' + lib.concatMapStrings (cert: ''
            - name: ${cert}
              kind: Secret
              group: ""
  '') config.services.envoyGateway.appCerts;

  # Envoy Gateway 资源清单 (GatewayClass + Gateway + ConfigMap patch)
  envoyGatewayManifest = pkgs.writeText "envoy-gateways.yaml" ''
    apiVersion: gateway.networking.k8s.io/v1
    kind: GatewayClass
    metadata:
      name: envoy
    spec:
      controllerName: gateway.envoyproxy.io/gatewayclass-controller
    ---
    # 配置 Envoy proxy 使用 IfNotPresent 策略，优先使用本地镜像
    # 指定使用本地已有的镜像地址（避免 CRI 无法识别 docker.io tag 的问题）
    apiVersion: gateway.envoyproxy.io/v1alpha1
    kind: EnvoyProxy
    metadata:
      name: default
      namespace: envoy-gateway-system
    spec:
      provider:
        type: Kubernetes
        kubernetes:
          envoyDaemonSet:
            patch:
              type: StrategicMerge
              value:
                spec:
                  template:
                    spec:
                      containers:
                      - name: envoy
                        imagePullPolicy: IfNotPresent
                        image: docker.lizzie.fun/envoyproxy/envoy:distroless-v1.38.0
          envoyService:
            type: NodePort
            externalTrafficPolicy: Local
            patch:
              type: StrategicMerge
              value:
                spec:
                  ports:
                  - name: http
                    port: 80
                    nodePort: 80
                    protocol: TCP
                    targetPort: 10080
                  - name: https
                    port: 443
                    nodePort: 443
                    protocol: TCP
                    targetPort: 10443
                  - name: tcp-ssh
                    port: 22
                    nodePort: 22
                    protocol: TCP
                    targetPort: 10022
                  - name: udp-dns
                    port: 53
                    nodePort: 10053
                    protocol: UDP
                    targetPort: 10053
    ---
    # ── 统一 Gateway（单 Service，多 listeners，类似 Istio 模式）───
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: envoy-gateway
      namespace: envoy-gateway-system
    spec:
      gatewayClassName: envoy
      infrastructure:
        parametersRef:
          group: gateway.envoyproxy.io
          kind: EnvoyProxy
          name: default
      listeners:
      - name: http
        port: 80
        protocol: HTTP
        allowedRoutes:
          kinds:
            - kind: HTTPRoute
          namespaces:
            from: All
      - name: https
        port: 443
        protocol: HTTPS
        allowedRoutes:
          kinds:
            - kind: HTTPRoute
          namespaces:
            from: All
        tls:
          mode: Terminate
          certificateRefs:
${certRefsYaml}
      - name: tcp-ssh
        port: 22
        protocol: TCP
        allowedRoutes:
          kinds:
            - kind: TCPRoute
          namespaces:
            from: All
      - name: udp-dns
        port: 53
        protocol: UDP
        allowedRoutes:
          kinds:
            - kind: UDPRoute
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
  options = {
    services.envoyGateway.appCerts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        List of application certificate secrets to mount on the unified Gateway.
        These secrets are expected to be synced via Reflector from app namespaces.
      '';
    };
  };

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
        ${kubectl} apply --server-side --force-conflicts -f ${envoyGatewayManifest}
      '';
    };

    # ── Deploy Kubernetes Reflector ──────────────────────────
    systemd.services.deploy-reflector = {
    description = "Deploy emberstack/kubernetes-reflector for cross-namespace Secret sync";
    after = [ "kube-apiserver.service" ];
    wantedBy = lib.mkForce [];
    serviceConfig.Type = "oneshot";
    script = ''
      echo "[deploy-reflector] Installing Reflector..."
      ${kubectl} apply --server-side -f ${reflectorManifest}
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
