# K8s 集群节点定义
#
# 【用途】集中管理所有 K8s 节点的静态配置，由 k8s-lib.nix 的 mkK8sNode 函数消费
#
# 【字段说明】
#   hostname  - 系统主机名（networking.hostName）
#   ip        - 节点 IP 地址（eth0 接口 + kubernetes.masterAddress）
#   role      - 节点角色，决定导入哪些模块：
#               control = 仅控制平面（API Server、Scheduler、Controller Manager、etcd）
#               worker  = 仅工作节点（kubelet、kube-proxy）
#               combo   = 控制平面 + 工作节点合一（适合小集群）
#   imports   - 额外的 NixOS 模块列表（如复用 server/workstation 配置）
#
# 【参数】
#   user    - 用户名（用于 users.users.${user} 配置）
#   dataDir - 数据目录路径（用于 fileSystems 挂载点）
#
{ user, dataDir }:

let
  # 示例：小集群（combo 合一，省资源）
  smallCluster = import ./nodes/small-cluster.nix;

  # 示例：大集群（控制平面与工作节点分离，生产推荐）
  largeCluster = import ./nodes/large-cluster.nix;

  # 开发服务器（需要 dataDir 参数用于挂载数据盘）
  dev = import ./nodes/dxserver.nix { inherit dataDir; };
in
# 合并：小集群示例 + 大集群示例 + 开发节点
# 如果同名，后面的覆盖前面的（通常不会冲突）
smallCluster // largeCluster // dev
