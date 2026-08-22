# Quickshell 桌面 shell 单元
# 隶属 Hyprland 会话：运行时随其启动（由 de-session 的 desktop-hyprland.target 拉起）
{ config, pkgs, lib, user, ... }:

let
  cfg = config.wayland.windowManager.quickshell;

  # 启动脚本：WAYLAND_DISPLAY 优先用 de-session xdg-env-bootstrap 注入的，缺失时回退扫 socket
  startupScript = pkgs.writeShellScript "quickshell-startup" ''
    export PATH=${pkgs.quickshell}/bin:${pkgs.coreutils}/bin:${pkgs.findutils}/bin:/run/wrappers/bin:$PATH
    if [ -z "$WAYLAND_DISPLAY" ]; then
      wl=$(find /run/user/$UID -maxdepth 1 -name 'wayland-*' -type s 2>/dev/null | head -n 1)
      [ -n "$wl" ] && export WAYLAND_DISPLAY="$(basename "$wl")"
    fi
    exec quickshell -p ~/.config/quickshell
  '';
in
{
  options.wayland.windowManager.quickshell = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Quickshell 桌面 shell。默认启用——引入即启用，由 de-session 门控运行时启动";
    };
    shellDir = lib.mkOption {
      type = lib.types.path;
      default = ../../assets/quickshell;
      description = "QML shell 配置目录（内含 shell.qml 入口）";
    };
  };

  config = lib.mkIf cfg.enable {
    # 组件不感知 DE；DE → 组件 关联由 de-session 的 deComponents 集中表维护

    home-manager.users.${user} = {
      home.packages = [ pkgs.quickshell ];
      xdg.configFile."quickshell".source = cfg.shellDir;

      systemd.user.services.quickshell = {
        Unit = {
          Description = "Quickshell desktop shell (Hyprland session)";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = startupScript;
          Restart = "on-failure";
          RestartSec = "3s";
        };
        # 不设 WantedBy=graphical-session.target —— 仅由 de-session 的 desktop-hyprland.target 随 Hyprland 会话拉起
      };
    };
  };
}