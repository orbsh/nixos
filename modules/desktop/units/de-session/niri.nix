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

  # 闲置守护：超时锁屏（Noctalia 锁屏 UI）→ 再熄屏（wlopm DPMS），活动/苏醒恢复
  # swayidle 也需要 WAYLAND_DISPLAY，脚本同 noctalia 模式补足
  swayidleStartup = pkgs.writeShellScript "swayidle-startup" ''
    export PATH=${pkgs.coreutils}/bin:${pkgs.findutils}/bin:/run/wrappers/bin:$PATH
    if [ -z "$WAYLAND_DISPLAY" ]; then
      wl=$(find /run/user/$UID -maxdepth 1 -name 'wayland-*' -type s 2>/dev/null | head -n 1)
      [ -n "$wl" ] && export WAYLAND_DISPLAY="$(basename "$wl")"
    fi
    exec ${pkgs.swayidle}/bin/swayidle \
      timeout 600 '${pkgs.noctalia}/bin/noctalia msg session lock' \
      timeout 630 '${pkgs.wlopm}/bin/wlopm --off "*"' \
      after-resume '${pkgs.wlopm}/bin/wlopm --on "*"' \
      before-sleep '${pkgs.noctalia}/bin/noctalia msg session lock'
  '';
in
{
  programs.niri.enable = true;

  # 注册活跃检测谓词 → 供 de-session dispatcher 拉起 desktop-niri.target
  desktop.sessions.niri.predicate = "${pkgs.procps}/bin/pgrep -x niri";

  # niri 读取 ~/.config/niri/config.kdl（NixOS 层 programs.niri 只负责安装+注册会话，不管理配置）
  home-manager.users.${user} = {
    home.packages = [ pkgs.noctalia pkgs.swayidle pkgs.wlopm ];

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
        Description = "Idle daemon: auto-lock + DPMS off (niri session)";
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