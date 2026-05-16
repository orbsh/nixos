# K8s 集群节点定义
# 格式: { 主机名 = { hostname = "名称"; ip = "IP"; role = "角色"; imports = [ ... ]; }; }
{ user, dataDir }:
{
  # ── 控制节点（3 台，奇数保证 etcd 高可用） ─────────────
  k8s-ctrl-01 = { hostname = "k8s-ctrl-01"; ip = "192.168.1.11"; role = "control"; imports = []; };
  k8s-ctrl-02 = { hostname = "k8s-ctrl-02"; ip = "192.168.1.12"; role = "control"; imports = []; };
  k8s-ctrl-03 = { hostname = "k8s-ctrl-03"; ip = "192.168.1.13"; role = "control"; imports = []; };

  # ── 工作节点 ──────────────────────────────────────────
  k8s-worker-01 = { hostname = "k8s-worker-01"; ip = "192.168.1.21"; role = "worker"; imports = []; };
  k8s-worker-02 = { hostname = "k8s-worker-02"; ip = "192.168.1.22"; role = "worker"; imports = []; };

  # ── 组合节点（控制+工作合一，适合小集群/省资源） ──────
  k8s-combo-01 = { hostname = "k8s-combo-01"; ip = "192.168.1.31"; role = "combo"; imports = []; };

  # ── 特殊节点：复用现有 Server 配置 ─────────────
  k8s-dx-01 = {
    hostname = "k8s-dx-01";
    ip = "172.178.5.123";
    role = "combo";
    imports = [
      ../hosts/server   # 包含磁盘、硬件、网络、以及 modules/common/vm.nix (虚拟化支持)
    ];

    # ── 数据盘挂载 ──────────────────────────────────────
    fileSystems."${dataDir}" = {
      device = "/dev/disk/by-uuid/79967e21-e2d6-4fc4-a8a4-e45dedf211ef";
      fsType = "btrfs";
      options = [ "subvol=@" "compress=zstd" ];
    };

    # ── 额外 SSH 公钥 ────────────────────────────────────
    users.users.master.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAzNo0nUZQcEZBIubufcp0cC2x56Giul8iif1iWDRySb master@dx"
    ];

    # ── 节点特有 API Server SANs ─────────────────────────
    services.kubernetes.apiserver.extraSANs = [ "172.178.5.123" ];
  };
}
