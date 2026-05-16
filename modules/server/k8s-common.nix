{ pkgs, lib, ... }:
let
  # ── 容器运行时选择（二选一："crio" 或 "containerd"） ────
  runtime = "crio";

  # 根据运行时选择 socket 路径
  criSocket = {
    crio = "/run/crio/crio.sock";
    containerd = "/run/containerd/containerd.sock";
  }.${runtime};

  isCrio = runtime == "crio";
in {
  # ── 容器运行时启用 ────────────────────────────────────
  virtualisation.cri-o.enable = isCrio;
  virtualisation.containerd.enable = !isCrio;

  # ── CRI-O 容器运行时配置 ─────────────────────────────
  virtualisation.cri-o = {
    runtime = "crun";  # 设置默认运行时
    settings.crio = {
      image.default_transport = "docker://";
    };
  };

  # ── Containerd 容器运行时配置 ─────────────────────────
  virtualisation.containerd.settings = {
    plugins."io.containerd.grpc.v1.cri" = {
      sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9";
    };
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
    extraOpts = lib.concatStringsSep " " [
      "--container-runtime-endpoint=unix://${criSocket}"
      "--runtime-request-timeout=10m"
      "--max-pods=500"
    ];
    # CRI-O 模式下由 kubelet 统一管理 CNI 配置，避免与 CRI-O 模块的 etc 条目冲突
    cni.config = lib.mkIf isCrio [
      {
        cniVersion = "0.4.0";
        name = "crio-bridge";
        type = "bridge";
        bridge = "cni0";
        isGateway = true;
        ipMasq = true;
        hairpinMode = true;
        ipam = {
          type = "host-local";
          subnet = "10.85.0.0/16";
          routes = [ { dst = "0.0.0.0/0"; } ];
        };
      }
      {
        cniVersion = "0.4.0";
        name = "loopback";
        type = "loopback";
      }
    ];
  };

  # CRI-O 模式下禁用 CRI-O 模块自动创建的 CNI 文件条目
  # 使用 enable = false 让 etc 模块跳过这些条目，避免与 kubelet 的目录符号链接冲突
  environment.etc."cni/net.d/10-crio-bridge.conflist".enable = lib.mkIf isCrio (lib.mkForce false);
  environment.etc."cni/net.d/99-loopback.conflist".enable = lib.mkIf isCrio (lib.mkForce false);

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
}
