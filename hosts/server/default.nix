{ inputs, lib, ... }: {
  imports = [
    ./disk.nix  # disko 重新分区格式化配置（按需启用）

    inputs.disko.nixosModules.disko

    ./hardware-configuration.nix  # 始终导入：内核模块等非磁盘硬件配置
    # ── 核心系统预设 (sys, base, nix, users, network, extra, container) ──
    ../../modules/system/core.nix
    ../../modules/system/units/vm.nix
    ./wireguard.nix
    ../../modules/dev/server.nix
  ];
}
