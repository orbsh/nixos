{ inputs, ... }: {
  imports = [
    inputs.disko-stable.nixosModules.disko

    # 硬件配置（安装后由 NixOS 生成，或手动编写）
    # ./hardware-configuration.nix

    ../../modules/common/sys.nix
    ../../modules/common/base.nix
    ../../modules/common/users.nix
    ../../modules/common/network.nix
    ../../modules/common/container.nix
    ../../modules/common/extra.nix

    # Kubernetes 控制节点
    ../../modules/server/k8s-control.nix

    # 磁盘配置（按需修改）
    # ./disk.nix
  ];

  networking.hostName = "k8s-control";

  # ── 网络配置（按需修改） ─────────────────────────────
  # networking.interfaces.eth0.ipv4.addresses = [{
  #   address = "192.168.1.10";
  #   prefixLength = 24;
  # }];
  # networking.defaultGateway = "192.168.1.1";
  # networking.nameservers = [ "8.8.8.8" "8.8.4.4" ];

  system.stateVersion = "25.05";
}