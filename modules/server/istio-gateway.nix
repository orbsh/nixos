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
              service:
                type: NodePort
                ports:
                  - name: status-port
                    port: 15021
                    targetPort: 15021
                    # 不设 nodePort，仅供集群内部健康检查
                  - name: http2
                    port: 80
                    targetPort: 8080
                    nodePort: 80
                  - name: https
                    port: 443
                    targetPort: 8443
                    nodePort: 443
        egressGateways:
          - name: istio-egressgateway
            enabled: true
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

  # 强制清理 Istio 资源（处理 finalizers 卡住问题）
  cleanupIstio = pkgs.writeShellScript "cleanup-istio.sh" ''
    set -e
    KUBECTL="${kubectl}"

    echo "[cleanup-istio] Force-cleaning istio-system namespace..."

    # 1. 删除 Gateway 资源的 finalizers（最常见卡住原因）
    echo "[cleanup-istio] Removing Gateway finalizers..."
    for gw in $($KUBECTL get gateway -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null || true); do
      ns=$(echo $gw | cut -d/ -f1)
      name=$(echo $gw | cut -d/ -f2)
      $KUBECTL patch gateway $name -n $ns --type=json -p '[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true
    done

    # 2. 删除所有 Istio 相关 CRD 资源的 finalizers
    echo "[cleanup-istio] Removing Istio CR finalizers..."
    for crd in envoyfilter gateway httproute referencegrant tcproute tlsservice virtualservice wasmplugin; do
      for ns in $($KUBECTL get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null); do
        for item in $($KUBECTL get $crd -n $ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true); do
          $KUBECTL patch $crd $item -n $ns --type=json -p '[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true
        done
      done
    done

    # 3. 删除 istio-system 命名空间中所有资源的 finalizers
    echo "[cleanup-istio] Removing all istio-system resource finalizers..."
    for resource in $($KUBECTL api-resources --verbs=list --namespaced -o name 2>/dev/null | head -30); do
      for item in $($KUBECTL get $resource -n istio-system -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true); do
        $KUBECTL patch $resource $item -n istio-system --type=json -p '[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true
      done
    done

    # 4. 强制删除 istio-system 命名空间
    echo "[cleanup-istio] Deleting istio-system namespace..."
    $KUBECTL delete namespace istio-system --grace-period=0 --force 2>/dev/null || true

    # 5. 等待命名空间完全删除（最多 60 秒）
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
  '';

  # Gateway API CRD 文件
  gatewayApiCrdFile = pkgs.fetchurl {
    url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml";
    hash = "sha256-c7kbd/a+AjqMkslp/GZOW9OxoorqWerJ68kEYHNU2tI=";
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

    # ── Gateway API CRDs ──────────────────────────────────────
    systemd.services.deploy-gateway-api-crds = {
      description = "Deploy Gateway API Standard CRDs";
      after = [ "deploy-istio.service" ];
      wantedBy = lib.mkForce [];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "2min";
      };
      script = ''
        echo "Deploying Gateway API CRDs..."
        ${kubectl} apply -f ${gatewayApiCrdFile}
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

    # ── Gateway 资源 (web + ssh) ──────────────────────────────
    systemd.services.deploy-gateways = {
      description = "Deploy Gateway resources (web and ssh)";
      after = [ "deploy-gateway-api-crds.service" ];
      wantedBy = lib.mkForce [];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "2min";
      };
      script = ''
        echo "Deploying Gateway resources..."
        ${kubectl} apply -f ${gatewayManifest}
      '';
    };
  };
}
