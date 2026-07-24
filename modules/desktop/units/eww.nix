{ config, lib, pkgs, user, ... }:

let
  ewwDir = ../assets/eww;

  # 独立启动脚本，避免 bash -c '...' 内联引号与 systemd unit 解析冲突
  startupScript = pkgs.writeShellScript "eww-startup" ''
    export PATH=${pkgs.eww}/bin:${pkgs.coreutils}/bin:${pkgs.gawk}/bin:${pkgs.bash}/bin:${pkgs.iproute2}/bin:${pkgs.iw}/bin:${pkgs.gnugrep}/bin:${pkgs.procps}/bin:/run/wrappers/bin

    # 持续检测 Wayland socket（最多等待 10 秒）
    for i in $(seq 1 50); do
      wl_display=$(/usr/bin/find /run/user/$UID -maxdepth 1 -name "wayland-*" -type s 2>/dev/null | head -n 1)
      if [ -n "$wl_display" ]; then
        WAYLAND_DISPLAY=$(basename "$wl_display")
        break
      fi
      sleep 0.2
    done

    if [ -z "$WAYLAND_DISPLAY" ]; then
      echo "No WAYLAND_DISPLAY found after 10s, exiting" >&2
      exit 1
    fi

    export WAYLAND_DISPLAY
    export XDG_RUNTIME_DIR=/run/user/$UID
    ${pkgs.eww}/bin/eww daemon
    sleep 1
    ${pkgs.eww}/bin/eww open omni-tray
  '';
in
{
  home-manager.users.${user} = {
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

    # ── 登录自动启动 ────────────────────────────────────
    systemd.user.services.eww = {
      Unit = {
        Description = "Eww daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "forking";
        WorkingDirectory = "%h/.config/eww";
        ExecStart = startupScript;
        Restart = "on-failure";
        Environment = [
          "PATH=${pkgs.eww}/bin:${pkgs.coreutils}/bin:${pkgs.gawk}/bin:${pkgs.bash}/bin:${pkgs.iproute2}/bin:${pkgs.iw}/bin:${pkgs.gnugrep}/bin:${pkgs.procps}/bin:/run/wrappers/bin"
          "NO_AT_BRIDGE=1"
          "GDK_BACKEND=wayland"
          "XDG_SESSION_TYPE=wayland"
        ];
        RestartSec = "5s";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    # ── 休眠前关闭 eww ─────────────────────────────────
    systemd.user.services.eww-suspend-killer = {
      Unit = {
        Description = "Kill eww before suspend";
        Before = [ "sleep.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.procps}/bin/pkill -f eww || true";
      };
    };

    systemd.user.targets.sleep = {
      Unit = {
        Wants = [ "eww-suspend-killer.service" ];
      };
    };
  };
}
