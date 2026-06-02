# 完整桌面预设：工作站
# 含 Hyprland + 全部应用 + IM + 笔记本优化
{ pkgs, ... }: {
  imports = [
    ./units/accessibility.nix
    ./units/apps-core.nix
    ./units/apps-extra.nix
    ./units/apps-im.nix
    ./units/cosmic.nix
    ./units/greetd.nix
    ./units/fonts.nix
    ./units/hyprland.nix
    ./units/input-method.nix
    ./units/laptop.nix
    ./units/rime.nix
    ./units/zed.nix
  ];

  # Hyprland 合成器 + 完整辅助工具链
  wayland.windowManager.hyprland.enable = true;

  # ── 通用桌面工具 ─────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    wl-clipboard
  ];
}
