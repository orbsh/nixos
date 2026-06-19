# 完整桌面预设：工作站
# 含 Hyprland + 全部应用 + IM + 笔记本优化
{ pkgs, lib, config, ... }: {
  imports = [
    ./units/apps-core.nix
    ./units/apps-extra.nix
    ./units/apps-im.nix
    ./units/cosmic.nix
    ./units/hyprland.nix
    ./units/greetd.nix
    ./units/input-method.nix
    ./units/rime.nix
    ./units/fonts.nix
    ./units/accessibility.nix
    ./units/eww.nix
    ./units/laptop.nix
    ./units/networkmanager.nix
  ];

  # Hyprland 合成器 + 完整辅助工具链
  wayland.windowManager.hyprland.enable = true;

  # ── 通用桌面工具 ─────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    wl-clipboard
  ];

  # ── 合并各模块的 resume 命令 ───────────────────────
  powerManagement.resumeCommands = config.desktop.inputMethod.resumeCommands;
}
