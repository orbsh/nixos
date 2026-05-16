# Kubernetes 通用配置（CRI-O / Containerd 公共部分）
{ pkgs, lib, config, ... }: {
  # ── 声明容器运行时选项（必须由 k8s-lib.nix 显式设置） ──
  options.services.kubernetes.runtime = lib.mkOption {
    type = lib.types.enum [ "crio" "containerd" ];
    description = "Container runtime for Kubernetes nodes";
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
  # ── API Server SANs（通用地址） ────────────────────────
  # 节点特有 IP/域名由 nodes.nix 注入
  services.kubernetes.apiserver.extraSANs = [
    "127.0.0.1"
    "localhost"
    "kubernetes"
    "kubernetes.default"
    "kubernetes.default.svc"
    "kubernetes.default.svc.cluster.local"
  ];

  # 监听所有网络接口，允许远程访问
  services.kubernetes.apiserver.address = "0.0.0.0";

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
  };

  # ── CLI 工具 ───────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes-helm
  ];

  # ── 防火墙：通用端口 ───────────────────────────────────
  networking.firewall.allowedTCPPorts = [
    6443        # kube-apiserver（所有节点可能需要访问）
    10250       # kubelet API
  ];

  # NodePort 范围（1-32767，通过 iptables 直接配置）
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p tcp --dport 1:32767 -j nixos-fw-accept
  '';

  # ── 关闭 swap（k8s 要求） ──────────────────────────────
  swapDevices = lib.mkForce [];
  };  # config
}
