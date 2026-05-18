{ pkgs, lib, config, ... }: let
  kubeconfig = "/etc/kubernetes/cluster-admin.kubeconfig";
  kubectl = "${pkgs.kubectl}/bin/kubectl --kubeconfig ${kubeconfig}";
  istioctl = "${pkgs.istioctl}/bin/istioctl --kubeconfig ${kubeconfig}";

  # IstioOperator 配置：包含所有 gateway 设置
  istioOperator = pkgs.writeText "istio-operator.yaml" ''
    apiVersion: install.istio.io/v1alpha1
    kind: IstioOperator
    metadata:
      name: istio
      namespace: istio-system
    spec:
      profile: minimal
      components:
        ingressGateways:
          - name: istio-ingressgateway
            enabled: true
            k8s:
              replicas: 1
              service:
                type: NodePort
                ports:
                  - name: status-port
                    port: 15021
                    targetPort: 15021
                    nodePort: 15021
                  - name: http2
                    port: 80
                    targetPort: 8080
                    nodePort: 80
                  - name: https
                    port: 443
                    targetPort: 8443
                    nodePort: 443
      values:
        global:
          proxy:
            resources:
              requests:
                cpu: 100m
                memory: 128Mi
              limits:
                cpu: 500m
                memory: 256Mi
  '';

  # Gateway API CRD 文件
  gatewayApiCrdFile = pkgs.fetchurl {
    url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml";
    hash = "sha256-c7xbd/a+AjqMkslp/GZOW9OxoorqWerJ68kEYHNU2tI=";
  };

  # Gateway 资源清单 (web + ssh)
  gatewayManifest = pkgs.writeText "gateways.yaml" ''
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: web
      namespace: istio-system
    spec:
      addresses:
      - value: istio-ingressgateway.istio-system.svc.cluster.local
        type: Hostname
      gatewayClassName: istio
      listeners:
      - name: web-https
        port: 443
        protocol: HTTPS
        allowedRoutes:
          namespaces:
            from: Selector
            selector:
              matchLabels:
                shared-gateway-access: "true"
        tls:
          mode: Terminate
          certificateRefs:
            - name: cert-web
              kind: Secret
              group: core
      - name: web-http
        port: 80
        protocol: HTTP
        allowedRoutes:
          namespaces:
            from: Selector
            selector:
              matchLabels:
                shared-gateway-access: "true"
    ---
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: ssh
      namespace: istio-system
    spec:
      addresses:
      - value: istio-ingressgateway.istio-system.svc.cluster.local
        type: Hostname
      gatewayClassName: istio
      listeners:
      - name: ssh
        port: 22
        protocol: TCP
        allowedRoutes:
          namespaces:
            from: Selector
            selector:
              matchLabels:
                shared-gateway-access: "true"
  '';
in {
  config = {
    # ── Istio Gateway + Gateway API CRDs ─────────────────────
    # 使用 istioctl 部署 Istio（含 Gateway 配置）、Gateway API CRDs 和 Gateway 资源

    # ── Istio 安装（使用 IstioOperator）───────────────────────
    systemd.services.deploy-istio = {
      description = "Install Istio service mesh via IstioOperator";
      after = [ "kubelet.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        if ! ${kubectl} get namespace istio-system &>/dev/null; then
          echo "Installing Istio with IstioOperator..."
          ${istioctl} install -y -f ${istioOperator}
        else
          echo "Istio already installed, verifying configuration..."
          ${istioctl} install -y -f ${istioOperator} --skip-confirmation
        fi
      '';
    };

    # ── Gateway API CRDs ──────────────────────────────────────
    systemd.services.deploy-gateway-api-crds = {
      description = "Deploy Gateway API Standard CRDs";
      after = [ "deploy-istio.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        echo "Deploying Gateway API CRDs..."
        ${kubectl} apply -f ${gatewayApiCrdFile}
      '';
    };

    # ── Set ExternalTrafficPolicy to Local ────────────────────
    systemd.services.set-external-traffic-policy = {
      description = "Set externalTrafficPolicy to Local on istio-ingressgateway";
      after = [ "deploy-istio.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        echo "Setting externalTrafficPolicy to Local..."
        ${kubectl} patch svc -n istio-system istio-ingressgateway \
          -p '{"spec":{"externalTrafficPolicy":"Local"}}'
      '';
    };

    # ── Gateway 资源 (web + ssh) ──────────────────────────────
    systemd.services.deploy-gateways = {
      description = "Deploy Gateway resources (web and ssh)";
      after = [ "deploy-gateway-api-crds.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        echo "Deploying Gateway resources..."
        ${kubectl} apply -f ${gatewayManifest}
      '';
    };
  };
}
