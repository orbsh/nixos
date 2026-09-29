# mudra: chromium --app + CDP 外部可控浏览器模式
# https://github.com/orbsh/mudra
# 仓库部署到 ~/.config/mudra（developMode 二分，与 nvim/nushell 同架构）。
# 注意不能用 ~/.local/share/mudra——那是 mudrad 的运行时数据目录（store/profiles）。
# Rust 重写后 `mudra` / `mudrad` = 仓内 cargo 构建产物（release 优先、debug 回退，
# 同 developMode「本地 git 即真值」哲学；非开发模式的 store 快照无 target/，
# wrapper 明确报错）。守护进程由 systemd user 服务看管（graphical-session）。
{
  config,
  pkgs,
  lib,
  mudraSrc,
  mudraLocalPath,
  user,
  ...
}: let
  developMode = config.programs.developMode;

  # 报错文案里的构建指引：开发模式指本地 git 目录，非开发模式指 store 快照
  buildHint =
    if developMode
    then "cargo build --release in ${mudraLocalPath}"
    else "mudra binaries are not packaged in the store snapshot (desktop workstations run developMode)";

  # cargo 产物解析：release 优先、debug 回退（daemon 与 CLI 同一形状）
  resolveBin = name: ''
    BIN=""
    for profile in release debug; do
      cand="$HOME/.config/mudra/target/$profile/${name}"
      if [ -x "$cand" ]; then BIN="$cand"; break; fi
    done
    [ -n "$BIN" ] || { echo "${name}: no binary — ${buildHint}" >&2; exit 1; }
  '';

  # CLI：纯 8899 转发器，无会话环境要求
  mudra = pkgs.writeShellScriptBin "mudra" ''
    ${resolveBin "mudra"}
    exec "$BIN" "$@"
  '';

  # mudrad run 的环境装配（与手动前台跑同一形状）：
  # - daemon 有 env 闸门（WAYLAND/DISPLAY/XDG_RUNTIME_DIR/DBUS 缺一即硬拒），
  #   缺 WAYLAND 时 spawn 的 chromium 全 zombie——systemd user 环境不保证齐全，
  #   按本仓 walker.nix 模式扫 wayland socket 兜底。
  # - 资源路径：daemon 默认拼 MUDRA_HOME（~/.local/share/mudra）子路径，部署形态
  #   下扩展与面板产物都在配置目录侧，须显式指过去。
  mudradStart = pkgs.writeShellScript "mudrad-start" ''
    export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    if [ -z "$WAYLAND_DISPLAY" ]; then
      for i in $(seq 1 50); do
        wl=$(${pkgs.findutils}/bin/find "$XDG_RUNTIME_DIR" -maxdepth 1 -name "wayland-*" -type s 2>/dev/null | head -n 1)
        if [ -n "$wl" ]; then
          export WAYLAND_DISPLAY="$(basename "$wl")"
          break
        fi
        sleep 0.2
      done
    fi
    export DISPLAY="''${DISPLAY:-:0}"
    [ -z "$DBUS_SESSION_BUS_ADDRESS" ] && export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    export MUDRA_FRONTEND_DIR="$HOME/.config/mudra/frontend"
    export MUDRA_PANEL_DIST="$HOME/.config/mudra/crates/mudra-panel/dist"
    ${resolveBin "mudrad"}
    exec "$BIN" "$@"
  '';

  # 手跑入口：mudrad run（前台）；服务用同一脚本
  mudrad = pkgs.writeShellScriptBin "mudrad" ''
    exec ${mudradStart} "$@"
  '';
in {
  config.home-manager.users.${user} = {
    imports = [
      ({config, lib, ...}: {
        home.packages = [mudra mudrad];

        home.file.".config/mudra" =
          if developMode then {
            # 工作站开发模式：单符号链接指向本地开发目录（out-of-store，改代码即生效）
            source = config.lib.file.mkOutOfStoreSymlink mudraLocalPath;
            force = true;
          } else {
            # 服务器/只读模式：从 flake input 部署（单个 symlink 指向 store）
            source = mudraSrc;
            force = true;
          };

        # 守护进程看管：graphical-session 起来才跑（env 闸门 + chromium 需要会话）；
        # flock 单例在 mudrad 内部，重复拉起会干净退出。
        systemd.user.services.mudrad = {
          Unit = {
            Description = "mudrad — mudra browser-mode control daemon";
            PartOf = ["graphical-session.target"];
            After = ["graphical-session.target"];
          };
          Service = {
            Type = "exec";
            ExecStart = "${mudradStart} run";
            Restart = "on-failure";
            RestartSec = "5s";
          };
          Install = {
            WantedBy = ["graphical-session.target"];
          };
        };
      })
    ];
  };
}
