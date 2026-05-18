{ pkgs, lib, config, ... }: {
  # ── Cert-Manager + Issuers ─────────────────────────────────
  # Deploys cert-manager, IngressClass, and ClusterIssuers
  # (selfsigned, letsencrypt, letsencrypt-staging)

  options.services.kubernetes.certManager.email = lib.mkOption {
    type = lib.types.str;
    default = config.services.kubernetes.adminEmail;
    defaultText = lib.literalExpression "config.services.kubernetes.adminEmail";
    description = "Email for ACME registration (defaults to adminEmail)";
  };

  config = {
    # ── Cert-Manager Installation ───────────────────────────────
    systemd.services.deploy-cert-manager = {
    description = "Install cert-manager";
    after = [ "kubelet.service" ];
    wantedBy = lib.mkForce [];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "2min";
    };
    script = let
      kubectl = "${pkgs.kubectl}/bin/kubectl --kubeconfig /etc/kubernetes/cluster-admin.kubeconfig";
      certManagerVersion = "v1.18.2";
    in ''
      # Check if cert-manager is already installed
      if ! ${kubectl} get namespace cert-manager &>/dev/null; then
        echo "Installing cert-manager..."
        ${kubectl} apply -f https://github.com/cert-manager/cert-manager/releases/download/${certManagerVersion}/cert-manager.yaml
      else
        echo "cert-manager already installed"
      fi
    '';
  };

  # ── Wait for Cert-Manager Webhook ─────────────────────────
  systemd.services.wait-for-cert-manager-webhook = {
    description = "Wait for cert-manager webhook to be ready";
    after = [ "deploy-cert-manager.service" ];
    wantedBy = lib.mkForce [];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "6min";
    };
    script = let
      kubectl = "${pkgs.kubectl}/bin/kubectl --kubeconfig /etc/kubernetes/cluster-admin.kubeconfig";
    in ''
      echo "Waiting for cert-manager webhook..."
      for i in $(seq 1 100); do
        if ${kubectl} get pods -n cert-manager -l app.kubernetes.io/component=webhook | grep -q Running; then
          echo "cert-manager webhook is running"
          exit 0
        fi
        sleep 3
      done
      echo "ERROR: cert-manager webhook failed to start"
      exit 1
    '';
  };

  # ── IngressClass ──────────────────────────────────────────
  systemd.services.deploy-ingressclass = {
    description = "Deploy Istio IngressClass";
    after = [ "wait-for-cert-manager-webhook.service" ];
    wantedBy = lib.mkForce [];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "2min";
    };
    script = let
      kubectl = "${pkgs.kubectl}/bin/kubectl --kubeconfig /etc/kubernetes/cluster-admin.kubeconfig";
      ingressclassManifest = pkgs.writeText "ingressclass.yaml" ''
        apiVersion: networking.k8s.io/v1
        kind: IngressClass
        metadata:
          name: istio
        spec:
          controller: istio.io/ingress-controller
      '';
    in ''
      echo "Deploying IngressClass..."
      ${kubectl} apply -f ${ingressclassManifest}
    '';
  };

  # ── ClusterIssuers ────────────────────────────────────────
  systemd.services.deploy-issuers = {
    description = "Deploy cert-manager ClusterIssuers";
    after = [ "wait-for-cert-manager-webhook.service" ];
    wantedBy = lib.mkForce [];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "2min";
    };
    script = let
      kubectl = "${pkgs.kubectl}/bin/kubectl --kubeconfig /etc/kubernetes/cluster-admin.kubeconfig";
      email = config.services.kubernetes.certManager.email or "nash@iffy.me";
      issuersManifest = pkgs.writeText "issuers.yaml" ''
        apiVersion: cert-manager.io/v1
        kind: ClusterIssuer
        metadata:
          name: selfsigned
        spec:
          selfSigned: {}
        ---
        apiVersion: cert-manager.io/v1
        kind: ClusterIssuer
        metadata:
          name: letsencrypt
        spec:
          acme:
            server: https://acme-v02.api.letsencrypt.org/directory
            email: ${email}
            privateKeySecretRef:
              name: letsencrypt
            solvers:
            - http01:
                ingress:
                  class: istio
        ---
        apiVersion: cert-manager.io/v1
        kind: ClusterIssuer
        metadata:
          name: letsencrypt-staging
        spec:
          acme:
            server: https://acme-staging-v02.api.letsencrypt.org/directory
            email: ${email}
            privateKeySecretRef:
              name: letsencrypt-staging
            solvers:
            - http01:
                ingress:
                  class: istio
      '';
    in ''
      echo "Deploying ClusterIssuers..."
      ${kubectl} apply -f ${issuersManifest}
    '';
  };

  # ── 重建完成后打印 Cert-Manager 服务启动命令 ────────────────────
  system.activationScripts.cert-manager-reminder = {
    text = ''
      echo ""
      echo "=== Cert-Manager 部署服务启动命令 ==="
      echo ""
      echo "  sudo systemctl start deploy-cert-manager.service deploy-ingressclass.service deploy-issuers.service"
      echo ""
    '';
    deps = [];
  };
};
}
