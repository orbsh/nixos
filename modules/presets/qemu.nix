{ inputs, pkgs, lib, user, ... }: {
  imports = [
    inputs.disko.nixosModules.disko

    # 硬件配置由 hosts/qemu/default.nix 导入
    # ./hardware-configuration.nix
    # ./disk.nix

    # ── 核心系统预设 (sys, base, nix, users, network, extra, container) ──
    ../system/core.nix

    # 桌面环境 (QEMU 定制：最小预设，裁剪掉 hyprland/apps)
    ../desktop/mini.nix

    # 开发工具
    # ../../modules/dev
  ];

  # ── 用户环境配置 ──────────────────────────────────────
  home-manager.users.${user} = {
    imports = [
      ../home/desktop.nix
    ];
  };

  # QEMU/KVM guest: SPICE agent for clipboard sharing and auto-resolution
  services.spice-vdagentd.enable = true;

  # Use stable kernel for maximum guest compatibility
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  networking.hostName = "qemu";
}
