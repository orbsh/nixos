{ inputs, user, lib, ... }: {
  imports = [
    inputs.disko.nixosModules.disko  # 必须显式导入 disko 模块以激活 disk.nix
    ./hardware/disk.nix  # disko 重新分区格式化配置（按需启用）
    ./hardware/hardware-configuration.nix  # 始终导入：内核模块等非磁盘硬件配置
    # ── 核心系统预设 (sys, base, nix, users, network, extra, container) ──
    ../../modules/system/core.nix
    ../../modules/system/units/vm.nix
    ./hardware/wireguard.nix  # 内网隧道（物理网络配置）
    ../../modules/dev/server.nix
  ];

  # ── 用户环境配置 ──────────────────────────────────────
  home-manager.users.${user} = {
    imports = [
      ../../modules/home/headless.nix
    ];
  };
}
