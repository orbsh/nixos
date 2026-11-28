# 桌面预设 · full（COSMIC + Hyprland + Quickshell）满配工作站
# = base + apps-im + laptop + networkmanager + mudra
# walker 已于 2026-11-28 退出活跃树：启动器改用 Noctalia 内置 launcher，
# 原模块与资产移到 modules/legacy/desktop/{units/walker.nix,assets/{walker,elephant}}（保留不删）。
# 桌面子系统（cosmic/hyprland/quickshell/eww 及 DE→组件关联）统一由 de-session 引入，不在本层列明细。
{ pkgs, user, ... }: {
  imports = [
    ./base.nix                    # 继承 base（mini + apps-extra + rime）
    ./units/apps-im.nix
    ./units/laptop.nix
    ./units/networkmanager.nix
    # ../legacy/desktop/units/walker.nix   # 已移入 legacy（启动器改 Noctalia）
    ./units/mudra.nix
  ];

  # ── 通用桌面工具 ─────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    wl-clipboard
  ];
}