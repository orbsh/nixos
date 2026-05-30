{ pkgs, ... }: {
  imports = [
    ./cosmic.nix
    ./hyprland.nix
    ./input-method.nix
    ./fonts.nix
    ./eww.nix
  ];

  # Hyprland 默认不启用，需要时在主机配置中开启：
  wayland.windowManager.hyprland.enable = true;

  # ── 通用桌面工具 ─────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    wl-clipboard
  ];
}
