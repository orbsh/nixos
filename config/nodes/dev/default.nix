# 开发服务器集群
# 用途：日常开发 + K8s combo 节点
# 特点：复用 server 完整配置，挂载数据盘，额外 SSH 密钥
{ dataDir, user }:
{
  # ── 集群级配置 ────────────────────────────────────────
  runtime = "containerd";  # 容器运行时：crio / containerd
  podCIDR = "10.1.0.0/16";  # 集群 Pod CIDR（需包含各节点 PodCIDR，如 10.1.1.0/24）
  adminEmail = "nash@iffy.me";  # 集群管理员邮箱

  # ── Envoy Gateway 证书管理 ────────────────────────────
  # 定义需要挂载到统一 Gateway 的应用证书列表（由 Reflector 同步）
  services.envoyGateway.appCerts = [
    "tls-warpgate"
    "tls-app-xmh"
  ];

  # ── 节点定义 ──────────────────────────────────────────
  nodes = {
    # 开发服务器（combo 角色）
    # 复用 server 配置：磁盘分区、硬件优化、网络设置、虚拟化支持
    dxserver = {
      hostname = "dxserver";
      ip = "172.178.5.123";
      role = "combo";
      imports = [
        ../../../hosts/server/hardware/disk.nix
        ../../../hosts/server/hardware/hardware-configuration.nix
        ../../../hosts/server/hardware/wireguard.nix
        ../../../modules/k8s/coredns.nix  # CoreDNS DNS 插件
      ];

      # ── CoreDNS 内网 DNS 服务 ──────────────────────────
      services.myCoredns = {
        templates = [
          { zone = "s"; answers = [ "172.178.5.123" ]; }
          { zone = "a"; answers = [ "172.178.1.37" ]; }
          { zone = "x"; answers = [ "172.178.1.58" "172.178.1.37" ]; }
        ];
        forward = {
          upstream = [
            "223.5.5.5"            # 阿里云
            "119.29.29.29"         # 腾讯云 / DNSPod
            "1.1.1.1"              # Cloudflare
          ];
          forceTcp = false;
        };
      };

      # ── 数据盘挂载 ──────────────────────────────────────
      # Btrfs 子卷 @ 挂载到 dataDir（由 flake 参数传入，如 /data）
      # 使用 zstd 压缩节省空间
      fileSystems."${dataDir}" = {
        device = "/dev/disk/by-uuid/79967e21-e2d6-4fc4-a8a4-e45dedf211ef";
        fsType = "btrfs";
        options = [ "subvol=@" "compress=zstd" ];
      };

      # ── 额外 SSH 公钥 ────────────────────────────────────
      # 允许特定密钥免密登录（格式：ssh-ed25519/ssh-rsa + 公钥 + 注释）
      users.users.${user}.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAzNo0nUZQcEZBIubufcp0cC2x56Giul8iif1iWDRySb ${user}@dx"
      ];

      # ── 节点特有 API Server SANs ─────────────────────────
      # 已由 k8s-libs.nix 自动为第一个 control/combo 节点注入
      # 如需额外 SAN，可在此追加：
      services.kubernetes.apiserver.extraSANs = [ "10.6.6.2" ];
    };
  };
}
