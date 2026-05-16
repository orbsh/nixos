# 开发服务器集群
# 用途：日常开发 + K8s combo 节点
# 特点：复用 server 完整配置，挂载数据盘，额外 SSH 密钥
{ dataDir }:
{
  # ── 集群级配置 ────────────────────────────────────────
  runtime = "containerd";  # 容器运行时：crio / containerd

  # ── 节点定义 ──────────────────────────────────────────
  nodes = {
    # 开发服务器（combo 角色）
    # 复用 server 配置：磁盘分区、硬件优化、网络设置、虚拟化支持
    dxserver = {
      hostname = "dxserver";
      ip = "172.178.5.123";
      role = "combo";
      imports = [
        ../../hosts/server
      ];

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
      users.users.master.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAzNo0nUZQcEZBIubufcp0cC2x56Giul8iif1iWDRySb master@dx"
      ];

      # ── 节点特有 API Server SANs ─────────────────────────
      # 允许通过此 IP 访问 API Server（用于远程 nixos-rebuild 或 kubectl）
      services.kubernetes.apiserver.extraSANs = [ "172.178.5.123" ];
    };
  };
}
