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
        # 版本与 hash 由 scripts/upstream.yml 的 cert-manager 条目维护（kind = release，flat hash）：
        #   nu scripts/upstream.nu bump cert-manager --write
        certManagerVersion = "v1.21.3";
        # 清单在 Nix 侧钉住（url + flat hash），激活时 apply store 里的文件——
        # 节点不再向 GitHub 现抓未校验的清单（ADR-001 远端源方式 A）
        certManagerManifest = pkgs.fetchurl {
          url = "https://github.com/cert-manager/cert-manager/releases/download/${certManagerVersion}/cert-manager.yaml";
          hash = "sha256-wEpRKVrdorGndRRnUflz54cZB3jH81GAhh2WeIduXHQ=";
        };
      in ''
        if ! ${kubectl} get namespace cert-manager &>/dev/null; then
          echo "Installing cert-manager ${certManagerVersion}..."
          ${kubectl} apply -f ${certManagerManifest}
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
        issuersManifest = pkgs.writeText "issuers.yaml" (
          builtins.replaceStrings [ "@EMAIL@" ] [ email ]
            (builtins.readFile "${./.}/assets/cert-issuers.yaml")
        );
      in ''
        echo "Deploying ClusterIssuers..."
        ${kubectl} apply -f ${issuersManifest}
      '';
    };

    # ── Default Fallback Certificate ──────────────────────────
    systemd.services.deploy-default-cert = {
      description = "Deploy default self-signed Certificate for Envoy Gateway fallback";
      after = [ "deploy-issuers.service" ];
      wantedBy = lib.mkForce [];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "2min";
      };
      script = let
        kubectl = "${pkgs.kubectl}/bin/kubectl --kubeconfig /etc/kubernetes/cluster-admin.kubeconfig";
        issuer = config.services.kubernetes.certIssuer;
        certManifest = pkgs.writeText "default-cert.yaml" (
          builtins.replaceStrings [ "@ISSUER@" ] [ issuer ]
            (builtins.readFile "${./.}/assets/default-cert.yaml")
        );
      in ''
        echo "Deploying default Certificate for tls-envoy-gateway (issuer: ${issuer})..."
        ${kubectl} apply -f ${certManifest}
      '';
    };

    # ── 重建完成后打印 Cert-Manager 服务启动命令 ────────────────────
    system.activationScripts.cert-manager-reminder = {
      text = ''
        echo ""
        echo "=== Cert-Manager 部署服务启动命令 ==="
        echo ""
        echo "  sudo systemctl start deploy-cert-manager.service deploy-issuers.service deploy-default-cert.service"
        echo ""
      '';
      deps = [];
    };
  };
}