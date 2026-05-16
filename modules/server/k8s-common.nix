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
    # 统一由 kubelet 管理 CNI 配置，避免与 CRI-O 的 environment.etc 条目冲突
    cni.config = lib.mkIf config.virtualisation.cri-o.enable [
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

  # 禁用 CRI-O 模块自动创建的 CNI 文件条目
  # 使用 enable = false 让 etc 模块跳过这些条目，避免与 kubelet 的目录符号链接冲突
  environment.etc."cni/net.d/10-crio-bridge.conflist".enable = lib.mkIf config.virtualisation.cri-o.enable (lib.mkForce false);
  environment.etc."cni/net.d/99-loopback.conflist".enable = lib.mkIf config.virtualisation.cri-o.enable (lib.mkForce false);

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
