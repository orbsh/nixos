# 基础桌面预设：便携系统
# 含 Hyprland + 核心应用
{ pkgs, lib, config, ... }: {
  imports = [
    ./units/cosmic.nix
    ./units/greetd.nix
    ./units/input-method.nix
    ./units/fonts.nix
    ./units/accessibility.nix
    ./units/apps-core.nix
    ./units/hyprland.nix
    ./units/eww.nix
  ];

  # Hyprland 合成器 + 完整辅助工具链
  wayland.windowManager.hyprland.enable = true;

  # ── 合并各模块的 resume 命令 ───────────────────────
  powerManagement.resumeCommands = config.desktop.inputMethod.resumeCommands;
}
