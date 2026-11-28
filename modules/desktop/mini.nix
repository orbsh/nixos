# 最小桌面预设：QEMU 虚拟机（层级根）
# base/full 在此基础层层叠加：base = mini + apps-extra + rime；full = base + apps-im + laptop + networkmanager + walker
{ pkgs, user, theme, ... }: {
  imports = [
    ./units/theme.nix             # 主题选择（desktop.theme → _module.args.theme）
    ./units/apps-core.nix
    ./units/de-session            # 桌面子系统（niri + DE→组件关联表）
    ./units/greetd.nix            # 登录管理器（greetd + tuigreet TUI）
    ./units/input-method.nix
    ./units/fonts.nix
    ./units/accessibility.nix
    # ./units/qutebrowser.nix      # 已弃用（2026-11-12）：nixpkgs 标记 qutebrowser-3.7.0 为 insecure（eMudhra 中间证书事件，QtWebEngine 不检查吊销）；模块归档在 modules/legacy/desktop/units/qutebrowser.nix
    ./units/rbw.nix
    ./units/kde-qt-theme.nix     # KDE/Qt 配色：Dolphin 等 Qt 应用（跟随 desktop.theme）
    ./units/herdr-prebuilt.nix   # herdr 官方二进制 overlay（声明 herdr.prebuilt 选项）
  ];

  # ── 桌面 Home Manager 配置（base/full 继承） ──────────────
  home-manager.users.${user} = {
    # HM 是独立 module 系统，NixOS 侧的 _module.args.theme 进不去，这里桥一次，
    # 让 home-terminals / herdr 这些 HM 单元也能用参数 `theme`。
    _module.args.theme = theme;

    imports = [
      ./units/home-terminals.nix
      ./units/home-xdg.nix
      # ../legacy/desktop/units/zellij.nix      # Zellij 终端复用（未引入）
      ./units/herdr.nix         # herdr 终端复用
    ];
  };
}