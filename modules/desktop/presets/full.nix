{ pkgs, ... }: {
  imports = [
    ../accessibility.nix
    ../apps-core.nix
    ../apps-extra.nix
    ../apps-im.nix
    ../cosmic.nix
    ../eww.nix
    ../fcitx5.nix
    ../fonts.nix
    ../hyprland.nix
    ../input-method.nix
    ../laptop.nix
    ../vivaldi.nix
    ../zed.nix
  ];

  # Hyprland 默认不启用，需要时在主机配置中开启：
  wayland.windowManager.hyprland.enable = true;

  # ── 通用桌面工具 ─────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    wl-clipboard
  ];
}
