# 最小桌面预设：QEMU 虚拟机（层级根）
# base/full 在此基础层层叠加：base = mini + apps-extra + rime；full = base + apps-im + laptop + networkmanager + walker
{ pkgs, user, ... }: {
  imports = [
    ./units/apps-core.nix
    ./units/de-session            # 桌面子系统（cosmic/hyprland/quickshell/eww + DE→组件关联表）
    ./units/greetd.nix            # 登录管理器（会话选择 + 记忆）
    ./units/input-method.nix
    ./units/fonts.nix
    ./units/accessibility.nix
    ./units/qutebrowser.nix
    ./units/rbw.nix
  ];

  # ── 桌面 Home Manager 配置（base/full 继承） ──────────────
  home-manager.users.${user} = {
    imports = [
      ./units/home-terminals.nix
      ./units/home-xdg.nix
    ];
  };
}