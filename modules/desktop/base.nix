# 基础桌面预设：便携系统
# 含 Hyprland + 核心应用
{ pkgs, lib, config, user, ... }: {
  imports = [
    ./units/apps-core.nix
    ./units/apps-extra.nix
    ./units/cosmic.nix
    ./units/hyprland.nix
    ./units/greetd.nix
    ./units/input-method.nix
    ./units/rime.nix
    ./units/fonts.nix
    ./units/accessibility.nix
    ./units/eww.nix
    ./units/qutebrowser.nix
    ./units/rbw.nix
    ./units/walker.nix
  ];

  # Hyprland 合成器 + 完整辅助工具链
  wayland.windowManager.hyprland.enable = false;

  # ── 桌面 Home Manager 配置 ───────────────────────
  home-manager.users.${user} = {
    imports = [
      ./units/home-terminals.nix
      ./units/home-xdg.nix
    ];
  };

  # ── 合并各模块的 resume 命令 ───────────────────────
  powerManagement.resumeCommands = config.desktop.inputMethod.resumeCommands;
}
