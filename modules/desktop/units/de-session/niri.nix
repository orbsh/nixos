# Niri 桌面子系统单元
# 归属：登录时于 greetd 选择 niri 会话启动；组件经 de-session 的 desktop-niri.target 拉起。
# 纳入由 imports 决定（引本单元 = 装 niri），运行时有 dispatcher 按活跃 DE 拉起其 target。
{ config, pkgs, lib, user, ... }:

let
  # 桌面 shell（Noctalia）启动脚本：补 WAYLAND_DISPLAY，回退扫 socket（同 quickshell 模式）
  noctaliaStartup = pkgs.writeShellScript "noctalia-startup" ''
    export PATH=${pkgs.coreutils}/bin:${pkgs.findutils}/bin:/run/wrappers/bin:$PATH
    if [ -z "$WAYLAND_DISPLAY" ]; then
      wl=$(find /run/user/$UID -maxdepth 1 -name 'wayland-*' -type s 2>/dev/null | head -n 1)
      [ -n "$wl" ] && export WAYLAND_DISPLAY="$(basename "$wl")"
    fi
    exec ${pkgs.noctalia}/bin/noctalia
  '';

  # 熄屏 +（不插电则）suspend：依据 /sys/class/power_supply/BAT1/status。
  # 熄屏用 niri 原生命令（niri msg action power-off-monitors，走 DPMS）——
  # wlopm 依赖 wlr-output-power-management-v1 协议，niri 不实现，改用它无效。
  # 由 swayidle timeout 630 触发；脚本需 WAYLAND_DISPLAY/NIRI_SOCKET（继承自 swayidle）。
  idleOff = pkgs.writeShellScript "niri-idle-off" ''
    if [ "$(cat /sys/class/power_supply/BAT1/status 2>/dev/null)" = "Discharging" ]; then
      /run/current-system/sw/bin/systemctl suspend
    else
      # 插电：仅熄屏
      ${pkgs.procps}/bin/pgrep -x niri >/dev/null && ${pkgs.niri}/bin/niri msg action power-off-monitors
    fi
  '';

  # 闲置守护：超时锁屏（Noctalia 锁屏 UI）→ 再熄屏 → 不插电时额外 suspend。
  swayidleStartup = pkgs.writeShellScript "swayidle-startup" ''
    export PATH=${pkgs.coreutils}/bin:${pkgs.findutils}/bin:/run/wrappers/bin:$PATH
    if [ -z "$WAYLAND_DISPLAY" ]; then
      wl=$(find /run/user/$UID -maxdepth 1 -name 'wayland-*' -type s 2>/dev/null | head -n 1)
      [ -n "$wl" ] && export WAYLAND_DISPLAY="$(basename "$wl")"
    fi
    # swayidle 由 niri 会话拉起时已带 NIRI_SOCKET；这里按 same 惯例回退推导
    if [ -z "$NIRI_SOCKET" ] && [ -n "$WAYLAND_DISPLAY" ]; then
      export NIRI_SOCKET="$(find /run/user/$UID -maxdepth 1 -name "niri.$WAYLAND_DISPLAY.*.sock" 2>/dev/null | head -n 1)"
    fi
    exec ${pkgs.swayidle}/bin/swayidle \
      timeout 600 '${pkgs.noctalia}/bin/noctalia msg session lock' \
      timeout 630 '${idleOff}' \
      after-resume '${pkgs.niri}/bin/niri msg action power-on-monitors' \
      before-sleep '${pkgs.noctalia}/bin/noctalia msg session lock'
  '';
in
{
  programs.niri.enable = true;

  # 注册活跃检测谓词 → 供 de-session dispatcher 拉起 desktop-niri.target
  desktop.sessions.niri.predicate = "${pkgs.procps}/bin/pgrep -x niri";

  # niri 读取 ~/.config/niri/config.kdl（NixOS 层 programs.niri 只负责安装+注册会话，不管理配置）
  home-manager.users.${user} = {
    home.packages = [ pkgs.noctalia pkgs.swayidle ];

    xdg.configFile."niri/config.kdl" = {
      source = ../../assets/niri/config.kdl;
      force = true;   # 覆盖可能遗留的本地 config
    };

    # Noctalia v5 配置（`assets/noctalia/config.toml` 独立文件）
    xdg.configFile."noctalia/config.toml" = {
      source = ../../assets/noctalia/config.toml;
      force = true;   # 覆盖 GUI 可能写出的占位
    };

    # cwdhist provider 脚本（启动器 /cwd 前缀查询用；以 python3 调用，无需 +x）
    xdg.configFile."noctalia/cwdhist.py" = {
      source = ../../assets/noctalia/cwdhist.py;
    };

    systemd.user.services.noctalia = {
      Unit = {
        Description = "Noctalia desktop shell (niri session)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = noctaliaStartup;
        Restart = "on-failure";
        RestartSec = "3s";
      };
      # 不设 WantedBy=graphical-session.target —— 仅由 de-session 的 desktop-niri.target 随 niri 会话拉起
    };

    systemd.user.services.swayidle = {
      Unit = {
        Description = "Idle daemon: auto-lock + DPMS off + suspend on battery (niri session)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" "noctalia.service" ];
      };
      Service = {
        Type = "simple";
        ExecStart = swayidleStartup;
        Restart = "on-failure";
        RestartSec = "3s";
      };
    };
  };
}