{ inputs, pkgs, lib, user, ... }: {
  imports = [
    inputs.disko.nixosModules.disko

    # 硬件配置由 hosts/qemu/default.nix 导入
    # ./hardware-configuration.nix
    # ./disk.nix

    # ── 核心系统预设 (sys, base, nix, users, network, extra, container) ──
    ../system/core.nix
    ../system/home.nix

    # 桌面环境 (QEMU 最小预设：Hyprland + 基础组件)
    ../desktop/mini.nix
    ../desktop/home.nix

    # 开发工具
    ../dev/server.nix
  ];


  # QEMU/KVM guest: SPICE agent for clipboard sharing and auto-resolution
  services.spice-vdagentd.enable = true;

  # ── 自动登录（免密码）─────────────────────────────────
  # 用户无密码 + greetd 自动进入 Hyprland
  users.users.${user} = {
    initialPassword = "";
  };

  services.greetd.settings.initial_session = {
    command = "${pkgs.hyprland}/bin/Hyprland";
    user = user;
  };

  networking.hostName = "qemu";
}
