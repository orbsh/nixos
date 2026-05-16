# K8s 集群节点定义
#
# 【用途】集中管理所有 K8s 节点的静态配置，由 k8s-lib.nix 的 mkK8sNode 函数消费
#
# 【数据结构】
#   每个集群文件返回 { runtime = "..."; nodes = { name = { ... }; }; }
#   runtime  - 集群级容器运行时（crio / containerd），该集群所有节点共享
#   nodes    - 节点定义 attrset，每个节点包含 hostname、ip、role、imports 等
#
# 【节点字段说明】
#   hostname  - 系统主机名（networking.hostName）
#   ip        - 节点 IP 地址（eth0 接口 + kubernetes.masterAddress）
#   role      - 节点角色：control / worker / combo
#   imports   - 额外的 NixOS 模块列表
#
# 【参数】
#   user    - 用户名（用于 users.users.${user} 配置）
#   dataDir - 数据目录路径（用于 fileSystems 挂载点）
#
{ user, dataDir }:

let
  # 各集群定义（运行时 + 节点列表）
  clusters = {
    dev           = import ./nodes/dev.nix { inherit dataDir; };
    smallCluster  = import ./nodes/small-cluster.nix;
    largeCluster  = import ./nodes/large-cluster.nix;
  };
in
# 返回集群结构，由 flake 层负责展平并添加集群前缀
{ inherit clusters; }
