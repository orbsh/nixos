# Kubernetes 通用配置（CRI-O / Containerd 公共部分）
{ pkgs, lib, config, cni0IP, user, publicDnsServers, ... }: {
  imports = [
    ../dev/server.nix
  ];

  # ── 声明容器运行时选项（必须由 k8s-libs.nix 显式设置） ──
  options.services.kubernetes.runtime = lib.mkOption {
    type = lib.types.enum [ "crio" "containerd" ];
    description = "Container runtime for Kubernetes nodes";
  };

  options.services.kubernetes.adminEmail = lib.mkOption {
    type = lib.types.str;
    description = "Cluster admin email address (used for ACME registration, etc.)";
  };

  options.services.kubernetes.certIssuer = lib.mkOption {
    type = lib.types.str;
    default = "selfsigned";
    description = "Default ClusterIssuer for Gateway TLS certificate (selfsigned | letsencrypt | letsencrypt-staging)";
  };

  options.services.kubernetes.podCIDR = lib.mkOption {
    type = lib.types.str;
    description = "Cluster Pod CIDR range (used by Flannel for network configuration)";
  };

  # 自定义防火墙端口选项：支持多模块声明、自动合并去重
  options.services.kubernetes.firewallPorts = lib.mkOption {
    type = lib.types.listOf lib.types.port;
    default = [];
    description = "K8s firewall ports, automatically merged from all modules.";
  };

  options.services.kubernetes.autoSyncCerts = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Auto-sync certificates from master node before kubelet starts (for worker/secondary nodes)";
  };

  options.services.kubernetes.useEasyCerts = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Use NixOS easyCerts for automatic certificate generation (disable for external CA)";
  };

  options.services.kubernetes.isCertServer = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Serve K8s certificates directory to other nodes via socat (for first control node)";
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
  # ── 禁用 home-manager 的 neovim 模块（nixpkgs 25.11 中 neovimUtils.makeVimPackageInfo 已移除）──
  # neovim 由系统级 NixOS 配置提供，插件由 lazy.nvim 管理
  home-manager.users.${user} = {
    programs.neovim.enable = lib.mkForce false;
  };

  # ── 自动证书管理 + Flannel + Proxy ─────────────────────
  # easyCerts 由 useEasyCerts 选项控制（默认启用）
  services.kubernetes.easyCerts = config.services.kubernetes.useEasyCerts;

  # ── 证书同步：Master 节点通过 socat 提供证书流 ─────────
  # 使用 fork 支持多节点并发请求，零状态，不依赖 HTTP/SSH
  systemd.services.k8s-cert-server = lib.mkIf config.services.kubernetes.isCertServer {
    description = "Serve K8s certificates to worker nodes via tar stream";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:9090,reuseaddr,fork EXEC:\"tar cz -C /var/lib/kubernetes/secrets . 2>/dev/null\"";
      Restart = "always";
    };
  };

  # 将 K8s 合并后的端口应用到系统防火墙（自动去重）
  networking.firewall.allowedTCPPorts = lib.unique config.services.kubernetes.firewallPorts;

  # ── 证书同步：非 master 节点在 kubelet 启动前从 master 拉取证书 ──
  systemd.services.sync-k8s-certs = lib.mkIf config.services.kubernetes.autoSyncCerts {
    description = "Sync K8s certificates from master node";
    before = [ "kubelet.service" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = let
      masterIP = config.services.kubernetes.masterAddress;
      nc = "${pkgs.netcat-openbsd}/bin/nc";
    in ''
      set -euo pipefail
      SECRETS_DIR="/var/lib/kubernetes/secrets"

      # 如果证书已存在且 CA 有效，跳过
      if [ -f "$SECRETS_DIR/ca.pem" ]; then
        if openssl x509 -in "$SECRETS_DIR/ca.pem" -noout -text >/dev/null 2>&1; then
          echo "[sync-k8s-certs] Certificates already exist and valid, skipping sync"
          exit 0
        fi
      fi

      echo "[sync-k8s-certs] Syncing certificates from master ${masterIP}:9090..."
      mkdir -p "$SECRETS_DIR"

      # 重试机制：master 可能尚未完全启动或生成证书
      SUCCESS=false
      for i in 1 2 3 4 5; do
        echo "[sync-k8s-certs] Attempt $i..."
        # 通过 nc 连接 socat，接收 tar.gz 流并直接解压
        if ${nc} -w 10 ${masterIP} 9090 | tar xz -C "$SECRETS_DIR" 2>/dev/null; then
          SUCCESS=true
          break
        fi
        sleep 3
      done

      # 验证证书是否成功同步
      if [ "$SUCCESS" = true ] && [ -f "$SECRETS_DIR/ca.pem" ]; then
        echo "[sync-k8s-certs] Certificates synced successfully"
        ls -la "$SECRETS_DIR/"
      else
        echo "[sync-k8s-certs] ERROR: Failed to sync certificates after 5 attempts"
        exit 1
      fi
    '';
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
    cni0IP
  ];

  # 监听所有网络接口，允许远程访问
  services.kubernetes.apiserver.bindAddress = "0.0.0.0";

  # NodePort 范围扩展 + Aggregated API 认证
  # 使用 NixOS 自动生成的 CA 作为 requestheader CA（与 proxy-client 证书匹配）
  services.kubernetes.apiserver.extraOpts = lib.concatStringsSep " " [
    "--allow-privileged=true"
    "--service-node-port-range=1-32767"
    "--requestheader-client-ca-file=/var/lib/kubernetes/secrets/ca.pem"
    "--requestheader-allowed-names=front-proxy-client"
    "--requestheader-extra-headers-prefix=X-Remote-Extra-"
    "--requestheader-group-headers=X-Remote-Group"
    "--requestheader-username-headers=X-Remote-User"
  ];

  # ── 修复 apiserver v1.36 PEM 序列化 bug ──────────────────
  # apiserver 写 extension-apiserver-authentication ConfigMap 时，
  # requestheader-client-ca-file 的 PEM 换行可能被吞掉变成空格，
  # 导致 metrics-server 无法验证代理请求。
  # 此服务在 apiserver 启动后检测并修复。
  systemd.services.fix-extension-apiserver-auth-certs = lib.mkIf (builtins.elem "master" config.services.kubernetes.roles) {
    description = "Fix apiserver extension-apiserver-authentication ConfigMap PEM serialization bug";
    after = [ "kube-apiserver.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = let
      kubectl = "${pkgs.kubectl}/bin/kubectl --kubeconfig=/etc/kubernetes/cluster-admin.kubeconfig";
      jq = "${pkgs.jq}/bin/jq";
    in ''
      set -euo pipefail
      CM="extension-apiserver-authentication"
      NS="kube-system"

      # 等待 apiserver 就绪
      echo "[fix-ext-api-certs] Waiting for apiserver..."
      for i in $(seq 1 30); do
        if ${kubectl} get configmap $CM -n $NS >/dev/null 2>&1; then
          break
        fi
        sleep 2
      done

      # 检查 requestheader-client-ca-file 行数
      LINES=$(${kubectl} get configmap $CM -n $NS -o jsonpath='{.data.requestheader-client-ca-file}' | wc -l)
      echo "[fix-ext-api-certs] requestheader-client-ca-file has $LINES lines"

      if [ "$LINES" -lt 3 ]; then
        echo "[fix-ext-api-certs] PEM corrupted (lines < 3), fixing..."
        CLIENT_CA=$(${kubectl} get configmap $CM -n $NS -o jsonpath='{.data.client-ca-file}')
        ${kubectl} get configmap $CM -n $NS -o json | \
          ${jq} --arg pem "$CLIENT_CA" '.data["requestheader-client-ca-file"] = $pem' | \
          ${kubectl} apply -f -
        echo "[fix-ext-api-certs] Fixed."
      else
        echo "[fix-ext-api-certs] PEM OK, no fix needed."
      fi
    '';
  };

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
    extraOpts = lib.concatStringsSep " " (baseKubeletOpts ++ [
      # 让 pod 内的 resolv.conf 直接指向公共 DNS
      # 避免 pod 内 127.0.0.1 指向容器 loopback（无 DNS 服务）
      # 宿主机 /etc/resolv.conf 可能指向本地 stub resolver（如 systemd-resolved 或本地 CoreDNS）
      # 但 pod 内 127.0.0.1 是容器 loopback，无法访问宿主机本地 DNS
      "--resolv-conf=/etc/kubelet-resolv.conf"
    ]);
    # Pod DNS 配置：指向 kube-dns ClusterIP
    clusterDns = [ "10.0.0.254" ];
    # 集群内部域名后缀
    clusterDomain = "cluster.local";
  };

  # ── kubelet resolv.conf ──
  # 有宿主机 CoreDNS 时：指向 cni0IP（pod 通过 cni0 网桥访问宿主机 CoreDNS）
  # 没有时：直接指向公共 DNS
  environment.etc."kubelet-resolv.conf".text =
    if config.services.coredns.enable or false then ''
      nameserver ${cni0IP}
      options ndots:5
    '' else ''
      ${lib.concatMapStringsSep "\n" (s: "nameserver ${s}") publicDnsServers}
      options ndots:5
    '';

  # ── CLI 工具 ───────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes-helm
    yq-go
  ];

  # ── 禁用 NixOS 自动 flannel（改由 k8s-addons.nix 声明式部署） ──
  # 不设置此项则 NixOS 会生成 11-flannel.conf 创建 mynet 网桥
  services.kubernetes.flannel.enable = lib.mkForce false;

  # ── 防火墙：通用端口 ───────────────────────────────────
  services.kubernetes.firewallPorts = [
    6443        # kube-apiserver（所有节点可能需要访问）
    10250       # kubelet API
  ];

  # NodePort 范围（1-32767）
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p tcp --dport 1:32767 -j nixos-fw-accept
  '';

  # ── 关闭 swap（k8s 要求） ──────────────────────────────
  swapDevices = lib.mkForce [];
  zramSwap.enable = lib.mkForce false;

  # ── CoreDNS 修复 ──────────────────────────────────────
  # 已由 k8s-addons.nix 统一管理（通过声明式 YAML patch）
  # 旧的 patch-coredns-env.service 已移除
  };  # config
}
