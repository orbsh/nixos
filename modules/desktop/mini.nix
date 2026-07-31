# 最小桌面预设：QEMU 虚拟机
# Hyprland + 基础组件，无 Cosmic/应用
{ pkgs, user, ... }: {
  imports = [
    ./units/apps-core.nix
    ./units/cosmic.nix
    ./units/hyprland.nix
    ./units/greetd.nix
    ./units/input-method.nix
    ./units/fonts.nix
    ./units/accessibility.nix
    ./units/eww.nix
    ./units/qutebrowser.nix
    ./units/rbw.nix
    ./units/walker.nix
  ];

  wayland.windowManager.hyprland.enable = false;

  # ── 桌面 Home Manager 配置 ───────────────────────
  home-manager.users.${user} = {
    imports = [
      ./units/home-terminals.nix
      ./units/home-xdg.nix
    ];
  };
}
