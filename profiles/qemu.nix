{ inputs, pkgs, lib, user, ... }: {
  imports = [
    inputs.disko.nixosModules.disko

    # 硬件配置由 hosts/qemu/default.nix 导入
    # ./hardware-configuration.nix
    # ./disk.nix

    # ── 核心系统预设 (sys, base, nix, users, network, extra, container) ──
    ../modules/system/core.nix

    # 桌面环境 (QEMU 最小预设：Hyprland + 基礎组件)
    ../modules/desktop/mini.nix

    # 开发工具
    ../modules/dev/server.nix

    ../modules/services/singbox.nix   # sing-box 代理组件（引入即起效，全直连占位）
    ../modules/services/ferron.nix     # Ferron 3.x 常驻服务（文件下载 + CGI 网关，port 8080）
  ];


  # QEMU/KVM guest: SPICE agent for clipboard sharing and auto-resolution
  services.spice-vdagentd.enable = true;

  # ── 自动登录（免密码）─────────────────────────────────
  # 用户无密码 + greetd 自动进入 COSMIC
  users.users.${user} = {
    initialPassword = "";
  };

  services.greetd.settings.initial_session = {
    command = "${pkgs.cosmic-session}/bin/cosmic-session";
    user = user;
  };

  networking.hostName = "qemu";
}
