{ inputs, lib, ... }: {
  imports = [
    ./disk.nix  # disko 重新分区格式化配置（按需启用）

    inputs.disko.nixosModules.disko

    ./hardware-configuration.nix  # 始终导入：内核模块等非磁盘硬件配置
    ../../modules/system/sys.nix
    ../../modules/system/base.nix
    ../../modules/system/nix.nix
    ../../modules/system/users.nix
    ../../modules/system/network.nix
    ./wireguard.nix
    ../../modules/system/container.nix
    ../../modules/system/extra.nix
    ../../modules/system/vm.nix
    ../../modules/dev/python.nix
  ];

  dev.python.enable = true;
}
