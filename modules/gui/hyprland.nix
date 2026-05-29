{ config, pkgs, lib, dataDir, ... }:

let
  cfg = config.wayland.windowManager.hyprland;
in {
  options.wayland.windowManager.hyprland.enable = lib.mkEnableOption "Hyprland 桌面环境（含完整辅助工具链）";

  config = lib.mkIf cfg.enable {
    # ── Hyprland 合成器 ────────────────────────────────────
    programs.hyprland.enable = true;

    # ── Pipewire Audio ─────────────────────────────────────
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;
    };



    # ── XDG Desktop Portal (Hyprland backend) ──────────────
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = "hyprland";
    };



    # ── 桌面环境辅助工具链 ─────────────────────────────────
    environment.systemPackages = with pkgs; [
      # 状态栏
      waybar

      # 应用启动器
      wofi

      # 通知守护进程
      mako

      # 截图 & 录屏
      grim
      slurp
      swappy

      # 壁纸管理
      hyprpaper

      # 剪贴板管理
      cliphist

      # 登出/锁屏菜单
      wlogout
      swaylock-effects

      # 媒体控制
      playerctl

      # 系统托盘 & 网络管理
      networkmanagerapplet
      pavucontrol

      # Python 脚本依赖
      (python3.withPackages (ps: [ ps.pyyaml ]))
    ];

    # ── 部署 toggle 脚本与 apps.yaml 配置到 /etc/hypr/ ──────
    environment.etc = {
      "hypr/scripts/hypr_toggle.py".source = ./hypr/scripts/hypr_toggle.py;
      "hypr/apps.yaml".source = ./hypr/apps.yaml;
    };

    # ── 快捷键：Focus Window (F1-F12) ───────────────────────
    environment.etc."hypr/keybinds.conf".source = ./assets/keybinds.conf;

    # 剪贴板历史由用户级 home-manager 配置管理
  };
}
