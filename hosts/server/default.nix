{ inputs, lib, ... }: {
  imports = [
    ./disk.nix  # disko 重新分区格式化配置（按需启用）

    inputs.disko.nixosModules.disko

    ./hardware-configuration.nix  # 始终导入：内核模块等非磁盘硬件配置
    # ── 核心系统预设 (sys, base, nix, users, network, extra, container) ──
    ../../modules/system/presets/core.nix
    ../../modules/system/vm.nix
    ./wireguard.nix
    ../../modules/dev/python.nix
  ];

  dev.python.enable = true;
}
