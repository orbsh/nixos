# 小集群示例（控制+工作合一，适合 1-3 台节点省资源）
#
# 角色：同时运行控制平面组件和 kubelet，允许调度普通 Pod
# 注意：combo 节点默认有 control-plane taint，k8s-lib.nix 会自动移除
{
  k8s-combo-01 = { hostname = "k8s-combo-01"; ip = "192.168.1.31"; role = "combo"; imports = []; };
  k8s-combo-02 = { hostname = "k8s-combo-02"; ip = "192.168.1.32"; role = "combo"; imports = []; };
  k8s-combo-03 = { hostname = "k8s-combo-03"; ip = "192.168.1.33"; role = "combo"; imports = []; };
}
