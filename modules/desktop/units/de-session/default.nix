# 桌面会话层：附属组件随 DE 走
# 分层：
#   - 组件（eww/quickshell/...）只定义自己的 systemd user 服务，不感知属于哪个 DE。
#   - DE → 组件 的关联表集中维护在本文件（deComponents），单一事实源。
#   - 纳入由 imports 决定（引该 DE 单元 = 装它），运行时由 dispatcher 按活跃 DE 拉起其 target。
# 机制：
#   - 每个 DE 一个 systemd user target（desktop-<de>.target），Wants 指向表中该 DE 的组件；
#   - dispatcher 在任意图形会话启动，检测当前活跃 DE，只拉起该 DE 的 target。
# 切换 DE 是登录时选会话（greetd 记住），不 rebuild。
# 纪律：组件单元的 WantedBy 只能由本层 target 拉起，绝不挂 graphical-session.target（否则任何会话都会启动）。
{ config, lib, pkgs, user, ... }:

let
  # ── DE → 组件 关联表（集中维护：hyprland 启动哪些，cosmic 启动哪些） ──
  # eww 已废弃（2026-08）：cosmic 用自带 shell，不再挂组件；系统监视挂件迁往 niri 的 Noctalia
  deComponents = {
    hyprland = [ "quickshell.service" ];
    niri = [ "noctalia.service" "swayidle.service" ];
  };

  # 已注册的 DE（由各 DE 单元声明 predicate）
  sessions = config.desktop.sessions;
  sessionNames = builtins.attrNames sessions;

  # dispatcher：等待任一 DE 谓词命中，启动其 target（一次登录只有一个活跃 DE）
  dispatcherScript = pkgs.writeShellScript "desktop-dispatcher" ''
    export PATH=${pkgs.procps}/bin:${pkgs.coreutils}/bin:/run/wrappers/bin:$PATH
    for i in $(seq 1 50); do
      ${lib.concatMapStringsSep "\n      " (name: ''
        if ${sessions.${name}.predicate} >/dev/null 2>&1; then
          echo "[desktop-dispatcher] active session: ${name}"
          systemctl --user start desktop-${name}.target
          exit 0
        fi
      '') sessionNames}
      sleep 0.2
    done
    echo "[desktop-dispatcher] no active desktop session detected" >&2
    exit 0
  '';

  # 把 WAYLAND_DISPLAY 导入 user 管理器（组件服务才能拿到，避免各自扫 socket）
  envBootstrap = pkgs.writeShellScript "wayland-env-bootstrap" ''
    export PATH=${pkgs.coreutils}/bin:/run/wrappers/bin:$PATH
    wl=$(find /run/user/$UID -maxdepth 1 -name 'wayland-*' -type s 2>/dev/null | head -n 1)
    [ -n "$wl" ] && systemctl --user set-environment WAYLAND_DISPLAY="$(basename "$wl")" XDG_RUNTIME_DIR="/run/user/$UID"
  '';
in
{
  # ── 捆绑本层管理的 DE 与组件（桌面子系统由此一层引入） ──
  imports = [
    ./niri.nix
    ./cosmic.nix
    ./hyprland.nix
    ./quickshell.nix
    # ./eww.nix  # 已废弃（2026-08），不再引入；文件保留备查
  ];

  options.desktop.sessions = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.predicate = lib.mkOption {
        type = lib.types.str;
        description = "活跃检测命令：命中视为该 DE 会话正在运行（由各 DE 单元声明）";
      };
    });
    default = { };
    description = "注册的桌面会话（DE）。DE → 组件的关联见本层 deComponents 集中表";
  };

  config = lib.mkIf (sessionNames != [ ]) {
    # 全部建在 home-manager.users.<user> 的 systemd --user 实例（与组件同一实例；de-session 自带定义，与顶层 NixOS systemd.user 无关）
    home-manager.users.${user} = {
      # 每个 DE → user target（Wants 引用集中表中该 DE 的组件）
      systemd.user.targets = lib.listToAttrs (map (name: lib.nameValuePair "desktop-${name}" {
        Unit = {
          Description = "Desktop session: ${name} components";
          PartOf = [ "graphical-session.target" ];
          Wants = deComponents.${name} or [ ];
          Before = deComponents.${name} or [ ];
        };
      }) sessionNames);

      # WAYLAND_DISPLAY 导入（图形会话启动一次）
      systemd.user.services."xdg-env-bootstrap" = {
        Unit = {
          Description = "Import WAYLAND_DISPLAY into user manager";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = envBootstrap;
          RemainAfterExit = true;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      # dispatcher：任意图形会话启动，按活跃 DE 拉起对应 target
      systemd.user.services."desktop-dispatcher" = {
        Unit = {
          Description = "Desktop session dispatcher (start active DE's components)";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" "xdg-env-bootstrap.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = dispatcherScript;
          RemainAfterExit = true;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}