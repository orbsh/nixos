{ inputs, ... }: {
  imports = [
    inputs.disko.nixosModules.disko

    ./hardware-configuration.nix  # 保留：内核模块、网络等硬件配置
    ../../modules/common/sys.nix
    ../../modules/common/base.nix
    ../../modules/common/users.nix
    ../../modules/common/network.nix
    ./wireguard.nix
    ../../modules/common/container.nix
    ../../modules/common/extra.nix

    # 集群调度二选一（取消注释需要的模块，注释另一个）
    # ../../modules/server/k8s-control.nix  # Kubernetes 控制节点
    # ../../modules/server/nomad.nix      # HashiCorp Nomad（已废弃，services.nomad 在 nixpkgs 25.11 中被上游移除）



    ./disk.nix
  ];

  networking.hostName = "server";
  system.stateVersion = "25.11";
}