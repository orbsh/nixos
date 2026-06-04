# modules/k8s/envoy-gateway.nix
# Envoy Gateway 配置模块（基于 Gateway API）
# 注意：此模块与 istio-gateway.nix 互斥，切换时需替换 imports
{ pkgs, lib, config, ... }: let
  kubeconfig = "/etc/kubernetes/cluster-admin.kubeconfig";
  kubectl = "${pkgs.kubectl}/bin/kubectl --kubeconfig ${kubeconfig}";

  assets = ./assets;

  # Gateway API CRD 文件 (experimental)
  gatewayApiCrdFile = ./assets/gateway-api-experimental.yaml;

  # Envoy Gateway 安装文件 (v1.8.0) — 本地管理，避免构建时下载
  envoyGatewayRawFile = ./assets/envoy-gateway-v1.8.0.yaml;

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

  # Kubernetes Reflector manifest for cross-namespace Secret sync
  # Adds a metrics Service (uses locally managed YAML to avoid runtime fetch)
  reflectorManifest = pkgs.writeTextFile {
    name = "reflector-patched.yaml";
    text =
      builtins.readFile "${./assets}/reflector.yaml"
      + ''
        ---
        apiVersion: v1
        kind: Service
        metadata:
          name: reflector-metrics
          namespace: kube-system
          labels:
            app.kubernetes.io/name: reflector
        spec:
          selector:
            app.kubernetes.io/name: reflector
          ports:
            - port: 8080
              targetPort: http
              protocol: TCP
              name: http
          type: ClusterIP
      '';
  };

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

  # Envoy Gateway 资源清单 (GatewayClass + EnvoyProxy + Gateway)
  envoyGatewayManifest = pkgs.writeText "envoy-gateways.yaml" (
    builtins.replaceStrings [ "@CERT_REFS@" ] [ certRefsYaml ]
      (builtins.readFile "${assets}/envoy-gateways.yaml")
  );

  # 清理脚本
  cleanupEnvoyGateway = pkgs.writeShellScript "cleanup-envoy-gateway.sh" ''
    exec ${assets}/cleanup-envoy-gateway.sh "${kubectl}"
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
        echo "[deploy-reflector] Installing Reflector...";
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
