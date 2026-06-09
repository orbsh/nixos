# 最小桌面预设：QEMU 虚拟机
# Hyprland + 基础组件，无 Cosmic/应用
{ pkgs, ... }: {
  imports = [
    ./units/hyprland.nix
    ./units/greetd.nix
    ./units/input-method.nix
    ./units/fonts.nix
    ./units/accessibility.nix
  ];

  wayland.windowManager.hyprland.enable = true;
}
