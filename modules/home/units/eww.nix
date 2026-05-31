{ config, lib, pkgs, ... }:

let
  ewwDir = ../assets/eww;
in
{
  programs.eww = {
    enable = true;
    yuckConfig = builtins.readFile "${ewwDir}/eww.yuck";
    scssConfig = builtins.readFile "${ewwDir}/eww.scss";
  };

  # 额外文件（widgets 和 scripts）通过 xdg.configFile 注入
  xdg.configFile."eww/widgets" = {
    source = "${ewwDir}/widgets";
    recursive = true;
  };

  xdg.configFile."eww/scripts" = {
    source = "${ewwDir}/scripts";
    recursive = true;
  };

  # 登录自动启动：绑定到 Wayland 图形会话，动态解析 WAYLAND_DISPLAY 确保 GTK 初始化成功
  systemd.user.services.eww = {
    Unit = {
      Description = "Eww daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      # 动态获取 WAYLAND_DISPLAY 并直接 exec eww，避免 wrapper 脚本导致 PID 跟踪丢失
      ExecStart = "${pkgs.bash}/bin/bash -c 'WAYLAND_DISPLAY=$(${pkgs.coreutils}/bin/ls /run/user/%U/wayland-* 2>/dev/null | ${pkgs.coreutils}/bin/head -n 1 | ${pkgs.findutils}/bin/xargs -r basename) && test -n \"$WAYLAND_DISPLAY\" && exec ${pkgs.eww}/bin/eww daemon || exit 1'";
      Restart = "on-failure";
      RestartSec = "3s";
      Environment = [
        "GDK_BACKEND=wayland"
        "QT_QPA_PLATFORM=wayland"
      ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
