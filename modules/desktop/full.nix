{ pkgs, ... }: {
  imports = [
    ./units/accessibility.nix
    ./units/apps-core.nix
    ./units/apps-extra.nix
    ./units/apps-im.nix
    ./units/cosmic.nix
    ./units/eww.nix
    ./units/fcitx5.nix
    ./units/fonts.nix
    ./units/hyprland.nix
    ./units/input-method.nix
    ./units/laptop.nix
    ./units/vivaldi.nix
    ./units/zed.nix
  ];

  # Hyprland 默认不启用，需要时在主机配置中开启：
  wayland.windowManager.hyprland.enable = true;

  # ── 通用桌面工具 ─────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    wl-clipboard
  ];
}
