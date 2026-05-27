# 大集群示例（控制平面与工作节点分离，适合生产环境）
#
# 控制节点：仅运行 API Server、Scheduler、Controller Manager、etcd
#           不调度普通 Pod，保证控制平面稳定性
# 工作节点：仅运行 kubelet + kube-proxy，负责实际 Pod 调度
{
  # ── 集群级配置 ────────────────────────────────────────
  runtime = "containerd";  # 容器运行时：crio / containerd
  podCIDR = "10.1.0.0/16";  # 集群 Pod CIDR（需包含各节点 PodCIDR，如 10.1.1.0/24）
  adminEmail = "admin@example.com";  # 集群管理员邮箱

  # ── 节点定义 ──────────────────────────────────────────
  nodes = {
    # ── 控制节点（3 台，奇数保证 etcd 高可用） ─────────────
    # 生产环境推荐 3 台（容忍 1 台故障）或 5 台（容忍 2 台故障）
    k8s-ctrl-01 = {
      hostname = "k8s-ctrl-01";
      ip = "192.168.1.11";
      role = "control";
      imports = [../../hosts/server];
      # fileSystems."/" = { device = "/dev/vda2"; fsType = "xfs"; autoResize = true; };
    };
    k8s-ctrl-02 = {
      hostname = "k8s-ctrl-02";
      ip = "192.168.1.12";
      role = "control";
      imports = [../../hosts/server];
      # fileSystems."/" = { device = "/dev/vda2"; fsType = "xfs"; autoResize = true; };
    };
    k8s-ctrl-03 = {
      hostname = "k8s-ctrl-03";
      ip = "192.168.1.13";
      role = "control";
      imports = [../../hosts/server];
      # fileSystems."/" = { device = "/dev/vda2"; fsType = "xfs"; autoResize = true; };
    };

    # ── 工作节点 ──────────────────────────────────────────
    k8s-worker-01 = {
      hostname = "k8s-worker-01";
      ip = "192.168.1.21";
      role = "worker";
      imports = [../../hosts/server];
      # fileSystems."/" = { device = "/dev/vda2"; fsType = "xfs"; autoResize = true; };
    };
    k8s-worker-02 = {
      hostname = "k8s-worker-02";
      ip = "192.168.1.22";
      role = "worker";
      imports = [../../hosts/server];
      # fileSystems."/" = { device = "/dev/vda2"; fsType = "xfs"; autoResize = true; };
    };
  };
}
