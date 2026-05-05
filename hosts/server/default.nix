{ inputs, lib, ... }: {
  imports = [
    ./existing-disk.nix  # 现有磁盘挂载配置（不格式化）
    # ./disk.nix  # disko 重新分区格式化配置（按需启用）

    inputs.disko.nixosModules.disko

    ./hardware-configuration.nix  # 始终导入：内核模块等非磁盘硬件配置
    ../../modules/common/sys.nix
    ../../modules/common/base.nix
    ../../modules/common/users.nix
    ../../modules/common/network.nix
    ./wireguard.nix
    ../../modules/common/container.nix
    ../../modules/common/extra.nix

    # 集群调度二选一（取消注释需要的模块，注释另一个）
    # ../../modules/server/k8s-control.nix  # Kubernetes 控制节点
  ];

  networking.hostName = "server";
  system.stateVersion = "25.11";
}