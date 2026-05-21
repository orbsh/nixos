{ inputs, lib, ... }: {
  imports = [
    # ./existing-disk.nix  # 现有磁盘挂载配置（不格式化）
    ./disk.nix  # disko 重新分区格式化配置（按需启用）

    inputs.disko.nixosModules.disko

    ./hardware-configuration.nix  # 始终导入：内核模块等非磁盘硬件配置
    ../../modules/common/sys.nix
    ../../modules/common/base.nix
    ../../modules/common/nix-tools.nix
    ../../modules/common/users.nix
    ../../modules/common/network.nix
    ./wireguard.nix
    ../../modules/common/container.nix
    ../../modules/common/extra.nix
    ../../modules/common/vm.nix
    ../../modules/dev/python.nix
  ];

  dev.python.enable = true;
}
