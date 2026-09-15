{ pkgs, lib, config, user, ... }: {
  options.desktop.inputMethod.resumeCommands = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "Commands to restart input method after resume.";
  };

  # ── Input Method: fcitx5 + Rime ──────────────────────
  config = {
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;
        addons = [
          pkgs.fcitx5-gtk
          pkgs.fcitx5-rime
          pkgs.rime-data
          pkgs.qt6Packages.fcitx5-configtool
          pkgs.qt6Packages.fcitx5-chinese-addons
        ];
      };
    };

    # Fix SVG icon skin rendering in tiling WMs
    programs.gdk-pixbuf.modulePackages = [ pkgs.librsvg ];

    # ── Fcitx5 休眠唤醒后自动重启 ────────────────────────
    # COSMIC 锁屏 SIGKILL 输入法 Applet 导致 Wayland IM 断联。
    # 系统级 resume hook 通过 runuser 触发用户级 fcitx5 重启。
    # 注意不 pkill -f fcitx5：多生命周期来源竞争是 profile 退化根因之一，
    # resume 重启只应kill显式服务实例再让 systemd 拉起。
    desktop.inputMethod.resumeCommands = ''
      ${pkgs.systemd}/bin/runuser -u master -- ${pkgs.systemd}/bin/systemctl --user restart fcitx5.service || true
    '';

    # ── fcitx5 显式 user service（方案 A：接管 xdg-autostart） ──
    # 根因：xdg-autostart generator 产物 After=graphical-session.target，与
    # Wayland socket 就绪存在时序竞争——fcitx5 抢跑则拿不到 input-method 全局
    # 对象，退化为仅 XWayland 模式且不重试，relogin 后 Wayland 原生应用全部
    # 无法切输入法。改为显式服务：等 WAYLAND_DISPLAY 导入后启动，失败自动重启。
    # 启动归属 desktop-niri.target（de-session 纪律：组件不挂 graphical-session.target）。
    home-manager.users.${user} = {
      # profile 不收 HM 管控：它是 fcitx5 运行时状态文件（UI configtool 的
      # 输入法组修改落在这里），管控会在每次 switch 覆盖用户 UI 操作。
      # 退化残留问题由服务层唯一生命周期（下方显式 service）解决。

      systemd.user.services.fcitx5 = {
        Unit = {
          Description = "Fcitx5 input method (niri session)";
          PartOf = [ "graphical-session.target" ];
          After = [
            "graphical-session.target"
            "xdg-env-bootstrap.service"
            # Conflicts 必须配 After：先等 autostart 实例完全停止（释放 dbus 名）
            # 再启动自己。否则濒死实例仍占着 org.fcitx.Fcitx5，本实例 dbus addon
            # 创建失败、退出码 0，Restart=on-failure 不触发，fcitx5 全灭。
            "app-org.fcitx.Fcitx5@autostart.service"
          ];
          Wants = [ "xdg-env-bootstrap.service" ];
          # 屏蔽 xdg-autostart generator 产物，避免双实例竞争
          Conflicts = [ "app-org.fcitx.Fcitx5@autostart.service" ];
        };
        Service = {
          Type = "simple";
          # ExecStart 必须用 i18n 模块拼好的包（fcitx5.addons 注入其中）：
          # 直接写 pkgs.qt6Packages.fcitx5-with-addons 不含 rime addon，
          # 启动时 profile 里的 rime 被判 invalid 删除，输入法组退化为 keyboard-us。
          ExecStart = "${config.i18n.inputMethod.package}/bin/fcitx5";
          Restart = "always";
          RestartSec = "3s";
        };
        # 不设 WantedBy —— 仅由 de-session 的 desktop-niri.target 随 niri 会话拉起
      };
    };
  };
}
