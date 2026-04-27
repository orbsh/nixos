{ pkgs, lib, config, ... }:
let
  # Nix 惰性求值：config 在此处是引用而非快照，
  # 实际求值时会看到最终合并后的值，保持一致。
  criSocket = if config.virtualisation.containerd.enable
    then "/run/containerd/containerd.sock"
    else "/run/crio/crio.sock";
in {
  # ── CRI-O 容器运行时（k8s 推荐运行时） ─────────────────
  virtualisation.cri-o = {
    enable = true;
    settings = {
      crio = {
        image.default_transport = "docker://";
        runtime.runtimes = {
          crun = {
            path = "${pkgs.crun}/bin/crun";
            allowed_annotations = [ "io.containerd.runc.v2.runc.options" ];
          };
        };
      };
    };
  };

  # ── Containerd 容器运行时（可选，默认禁用） ────────────
  virtualisation.containerd = {
    enable = false;
    settings = {
      plugins."io.containerd.grpc.v1.cri" = {
        sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9";
      };
    };
  };

  # ── k8s 所需内核模块 ────────────────────────────────────
  boot.kernelModules = [ "overlay" "br_netfilter" ];

  # ── k8s 所需系统参数 ────────────────────────────────────
  boot.kernel.sysctl = {
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.ipv4.ip_forward" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
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
    extraOptions = [
      "--container-runtime-endpoint=unix://${criSocket}"
      "--runtime-request-timeout=10m"
      "--max-pods=500"
    ];
  };

  # ── CLI 工具 ───────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    kubectl
    kubeadm
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