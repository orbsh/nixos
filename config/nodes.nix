# K8s 集群节点定义
# 格式: { 主机名 = { ip = "IP地址"; role = "角色"; }; }
# 角色可选: control / worker / combo
{
  # ── 控制节点（3 台，奇数保证 etcd 高可用） ─────────────
  k8s-ctrl-01 = { ip = "192.168.1.11"; role = "control"; };
  k8s-ctrl-02 = { ip = "192.168.1.12"; role = "control"; };
  k8s-ctrl-03 = { ip = "192.168.1.13"; role = "control"; };

  # ── 工作节点 ──────────────────────────────────────────
  k8s-worker-01 = { ip = "192.168.1.21"; role = "worker"; };
  k8s-worker-02 = { ip = "192.168.1.22"; role = "worker"; };

  # ── 组合节点（控制+工作合一，适合小集群/省资源） ──────
  k8s-combo-01 = { ip = "192.168.1.31"; role = "combo"; };
}