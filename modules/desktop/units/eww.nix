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

    # ── 清理僵尸 daemon ─────────────────────────────────
    # 若已有 daemon 但 ping 不通（进程卡死/socket 残留），
    # 强制结束并清 socket，避免 eww open 连上尸体导致窗口显示但不刷新。
    if ${pkgs.eww}/bin/eww ping >/dev/null 2>&1; then
      echo "eww daemon already alive, reusing"
    else
      echo "eww daemon unresponsive, cleaning up stale daemon"
      ${pkgs.procps}/bin/pkill -9 -x eww 2>/dev/null || true
      rm -f /run/user/$UID/eww-server_* 2>/dev/null || true
    fi

    ${pkgs.eww}/bin/eww daemon
    sleep 1
    ${pkgs.eww}/bin/eww open omni-tray
  '';
  # 探活脚本：daemon 进程在但 ping 不通 -> 判定卡死，kill 让 systemd 重启
  watchdogScript = pkgs.writeShellScript "eww-watchdog" ''
    export PATH=${pkgs.eww}/bin:${pkgs.coreutils}/bin:${pkgs.procps}/bin
    export XDG_RUNTIME_DIR=/run/user/$UID

    if pgrep -x eww >/dev/null 2>&1 && ! ${pkgs.eww}/bin/eww ping >/dev/null 2>&1; then
      echo "[eww-watchdog] daemon unresponsive, killing it (systemd Restart relaunches)"
      ${pkgs.procps}/bin/pkill -9 -x eww 2>/dev/null || true
      rm -f /run/user/$UID/eww-server_* 2>/dev/null || true
    fi
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

    # ── 探活 watchdog：定期 ping，卡死则 kill（systemd 自动重启） ──
    systemd.user.services.eww-watchdog = {
      Unit = {
        Description = "Eww daemon liveness watchdog";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = watchdogScript;
      };
    };

    systemd.user.timers.eww-watchdog = {
      Unit = {
        Description = "Periodic eww daemon liveness check";
        After = [ "graphical-session.target" ];
      };
      Timer = {
        OnBootSec = "1m";
        OnUnitActiveSec = "1m";
        Unit = "eww-watchdog.service";
      };
      Install = {
        WantedBy = [ "timers.target" ];
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
