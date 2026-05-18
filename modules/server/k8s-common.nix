# Kubernetes 通用配置（CRI-O / Containerd 公共部分）
{ pkgs, lib, config, ... }: {
  # ── 声明容器运行时选项（必须由 k8s-lib.nix 显式设置） ──
  options.services.kubernetes.runtime = lib.mkOption {
    type = lib.types.enum [ "crio" "containerd" ];
    description = "Container runtime for Kubernetes nodes";
  };

  options.services.kubernetes.adminEmail = lib.mkOption {
    type = lib.types.str;
    description = "Cluster admin email address (used for ACME registration, etc.)";
  };

  options.services.kubernetes.podCIDR = lib.mkOption {
    type = lib.types.str;
    description = "Cluster Pod CIDR range (used by Flannel for network configuration)";
  };

  config = let
    runtime = config.services.kubernetes.runtime;

  # 根据运行时选择 socket 路径
  criSocket = {
    crio = "/run/crio/crio.sock";
    containerd = "/run/containerd/containerd.sock";
  }.${runtime};

  # ── Kubelet 基础参数（可被子模块通过 config 模块扩展） ──
  baseKubeletOpts = [
    "--container-runtime-endpoint=unix://${criSocket}"
    "--runtime-request-timeout=10m"
    "--max-pods=500"
  ];
in {
  # ── 自动证书管理 + Flannel + Proxy ─────────────────────
  # roles 非空时会自动启用 easyCerts、flannel、proxy
  # 此处显式启用以确保
  services.kubernetes.easyCerts = true;

  # ── K8s 证书自动续期 ──────────────────────────────────
  # 每周检测证书有效期，到期前 30 天自动 rebuild
  # 注意：服务器上必须有 flake 配置才能自动续期
  systemd.services.renew-k8s-certs = {
    description = "Auto-renew Kubernetes certificates before expiration";
    serviceConfig.Type = "oneshot";
    script = ''
      SECRETS_DIR="/var/lib/kubernetes/secrets"
      THRESHOLD_DAYS=30
      CONFIG_DIR="/home/master/nixos"
      HOSTNAME=$(cat /etc/hostname)

      # 检查是否存在证书目录
      [ -d "$SECRETS_DIR" ] || exit 0

      # 查找所有 .pem 证书并检查过期时间
      EXPIRING=false
      for cert in $SECRETS_DIR/*.pem; do
        [ -f "$cert" ] || continue
        enddate=$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2)
        [ -z "$enddate" ] && continue
        end_epoch=$(date -d "$enddate" +%s 2>/dev/null) || continue
        now_epoch=$(date +%s)
        days_left=$(( (end_epoch - now_epoch) / 86400 ))
        if [ $days_left -lt $THRESHOLD_DAYS ] && [ $days_left -ge 0 ]; then
          echo "Certificate $(basename $cert) expires in $days_left days ($enddate)"
          EXPIRING=true
        fi
      done

      # 有证书即将过期，执行 rebuild
      if [ "$EXPIRING" = true ]; then
        echo "Certificates expiring soon, running nixos-rebuild..."
        if [ -d "$CONFIG_DIR" ]; then
          nix --extra-experimental-features 'nix-command flakes' build \
            "$CONFIG_DIR#nixosConfigurations.dev__dxserver.config.system.build.toplevel" \
            --no-link
          /run/current-system/bin/switch-to-configuration switch
          # TODO: 邮件通知（需要配置 SMTP）
          # 示例：curl --silent --url 'smtps://smtp.example.com:465' \
          #   --mail-from 'alert@example.com' --mail-rcpt 'admin@example.com' \
          #   --user 'alert@example.com:password' \
          #   -T <(echo -e "Subject: K8s Certs Renewed\n\nCertificates renewed on $(hostname)")
          logger -t k8s-certs "Certificates renewed and applied successfully"
        else
          echo "ERROR: NixOS config not found at $CONFIG_DIR. Manual rebuild required."
          # TODO: 邮件通知失败时发送告警
          logger -t k8s-certs "ERROR: Auto-renew failed - config not found at $CONFIG_DIR"
        fi
      else
        echo "All certificates are valid for more than $THRESHOLD_DAYS days"
      fi
    '';
  };

  systemd.timers.renew-k8s-certs = {
    description = "Timer for K8s certificate auto-renewal";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      RandomizedDelaySec = "6h";
      Persistent = true;
    };
  };

  # ── API Server SANs（通用地址） ────────────────────────
  # 节点特有 IP/域名由 nodes.nix 注入
  services.kubernetes.apiserver.extraSANs = [
    "127.0.0.1"
    "localhost"
    "kubernetes"
    "kubernetes.default"
    "kubernetes.default.svc"
    "kubernetes.default.svc.cluster.local"
    "10.1.1.1"  # cni0 桥接 IP（单节点集群中 Pod 访问 API Server 的地址）
  ];

  # 监听所有网络接口，允许远程访问
  services.kubernetes.apiserver.bindAddress = "0.0.0.0";

  # NodePort 范围扩展
  services.kubernetes.apiserver.extraOpts = "--service-node-port-range=1-32767";

  # ── k8s 所需内核模块 ────────────────────────────────────
  boot.kernelModules = [ "overlay" "br_netfilter" ];

  # ── k8s 所需系统参数 ────────────────────────────────────
  # 注意：bridge-nf-call-iptables、ip_forward、bridge-nf-call-ip6tables
  # 已由 nixpkgs kubelet 模块自动设置，此处仅保留额外参数
  boot.kernel.sysctl = {
    "fs.inotify.max_user_instances" = 8192;
  };

  # ── 系统 ulimits 配置 ───────────────────────────────────
  security.pam.loginLimits = [
    { domain = "*"; type = "soft"; item = "core"; value = "infinity"; }
    { domain = "*"; type = "hard"; item = "core"; value = "infinity"; }
    { domain = "*"; type = "soft"; item = "nofile"; value = 100000; }
    { domain = "*"; type = "hard"; item = "nofile"; value = 100000; }
    { domain = "*"; type = "soft"; item = "nproc"; value = 100000; }
    { domain = "*"; type = "hard"; item = "nproc"; value = 100000; }
  ];

  # ── Kubelet（所有节点） ────────────────────────────────
  services.kubernetes.kubelet = {
    enable = true;
    extraOpts = lib.concatStringsSep " " baseKubeletOpts;
    # Pod DNS 配置：指向 kube-dns ClusterIP
    clusterDns = [ "10.0.0.254" ];
    # 集群内部域名后缀
    clusterDomain = "cluster.local";
  };

  # ── CLI 工具 ───────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes-helm
    istioctl
  ];

  # ── 禁用 NixOS 自动 flannel（改由 k8s-addons.nix 声明式部署） ──
  # 不设置此项则 NixOS 会生成 11-flannel.conf 创建 mynet 网桥
  services.kubernetes.flannel.enable = lib.mkForce false;

  # ── 防火墙：通用端口 ───────────────────────────────────
  networking.firewall.allowedTCPPorts = [
    6443        # kube-apiserver（所有节点可能需要访问）
    10250       # kubelet API
  ];

  # NodePort 范围（1-32767）
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p tcp --dport 1:32767 -j nixos-fw-accept
  '';

  # ── 关闭 swap（k8s 要求） ──────────────────────────────
  swapDevices = lib.mkForce [];

  # ── CoreDNS 修复 ──────────────────────────────────────
  # 已由 k8s-addons.nix 统一管理（通过声明式 YAML patch）
  # 旧的 patch-coredns-env.service 已移除
  };  # config
}
