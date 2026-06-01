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

  # 登录自动启动：Type=forking 以支持 eww daemon 的后台分离模式
  systemd.user.services.eww = {
    Unit = {
      Description = "Eww daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "forking";
      WorkingDirectory = "%h/.config/eww";
      # 启动脚本：探测 Wayland Socket -> 启动 Daemon -> 打开窗口
      ExecStart = "${pkgs.bash}/bin/bash -c 'export PATH=${pkgs.coreutils}/bin:${pkgs.gawk}/bin:${pkgs.bash}/bin:${pkgs.iproute2}/bin:${pkgs.iw}/bin:${pkgs.gnugrep}/bin:${pkgs.procps}/bin:/run/wrappers/bin; for i in 1 2 3 4 5; do WAYLAND_DISPLAY=$(${pkgs.coreutils}/bin/ls /run/user/%U/wayland-* 2>/dev/null | ${pkgs.coreutils}/bin/head -n 1 | ${pkgs.findutils}/bin/xargs -r ${pkgs.coreutils}/bin/basename); if [ -n \"$WAYLAND_DISPLAY\" ]; then break; fi; sleep 0.2; done; if [ -z \"$WAYLAND_DISPLAY\" ]; then echo \"No WAYLAND_DISPLAY\"; exit 1; fi; export WAYLAND_DISPLAY; export XDG_RUNTIME_DIR=/run/user/%U; ${pkgs.eww}/bin/eww daemon && sleep 1 && ${pkgs.eww}/bin/eww open omni-tray'";
      Restart = "on-failure";
      RestartSec = "3s";
      # 注入 Nix 环境变量，确保 defpoll 脚本能找到 awk, cat, tr 等命令
      Environment = [
        "PATH=${pkgs.coreutils}/bin:${pkgs.gawk}/bin:${pkgs.bash}/bin:${pkgs.iproute2}/bin:${pkgs.iw}/bin:${pkgs.gnugrep}/bin:${pkgs.procps}/bin:/run/wrappers/bin"
        "NO_AT_BRIDGE=1"
        "GDK_BACKEND=wayland"
        "XDG_SESSION_TYPE=wayland"
      ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
