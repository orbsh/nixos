{ inputs, pkgs, lib, user, ... }: {
  imports = [
    ./existing-disk.nix
    # ./existing-btrfs.nix  # 现有磁盘挂载配置（不格式化）
    # ./disk.nix

    inputs.disko.nixosModules.disko

    ./hardware-configuration.nix  # 始终导入：内核模块等非磁盘硬件配置

    # ── 通用基础模块 (与 ISO 保持一致，确保工具链完整) ──
    # ── 核心系统预设 (sys, base, nix, users, network, extra, container) ──
    ../../modules/system/core.nix
    ../../modules/system/units/hardware-generic.nix  # 通用硬件配置
    ../../modules/system/units/vm.nix

    # ── 完整桌面环境 (含所有应用与驱动) ──
    ../../modules/desktop/full.nix
    ../../modules/podman/ladder.nix        # 代理容器
  ];

  # udisks2 用于自动挂载可移动设备（方便访问目标硬盘或 U 盘数据）
  services.udisks2.enable = true;

  # 自动登录 master 用户，启动即用
  networking.hostName = "portable";
  services.getty.autologinUser = user;

  # ── 图形界面配置 ──────────────────────────────────
  # wayland.windowManager.hyprland.enable = true;
  # services.displayManager.cosmic-greeter.enable = lib.mkForce false;
}
