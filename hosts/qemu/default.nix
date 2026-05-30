{ inputs, pkgs, lib, user, ... }: {
  imports = [
    inputs.disko.nixosModules.disko

    ./hardware-configuration.nix  # 保留：内核模块、网络等硬件配置
    ./disk.nix

    # ── 核心系统预设 (sys, base, nix, users, network, extra, container) ──
    ../../modules/system/core.nix

    # 桌面环境 (QEMU 定制：基础预设，裁剪掉 extra/hyprland)
    ../../modules/desktop/base.nix

    # 开发工具
    # ../../modules/dev
  ];

  # ── 用户环境配置 ──────────────────────────────────────
  home-manager.users.${user} = {
    imports = [
      ../../modules/home/desktop.nix
    ];
  };

  # QEMU/KVM guest: SPICE agent for clipboard sharing and auto-resolution
  services.spice-vdagentd.enable = true;

  # Use stable kernel for maximum guest compatibility
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  networking.hostName = "qemu";
}
