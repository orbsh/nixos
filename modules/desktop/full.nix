# 桌面预设 · full（COSMIC + Hyprland + Quickshell）满配工作站
# = base + apps-im + laptop + networkmanager + walker
# 桌面子系统（cosmic/hyprland/quickshell/eww 及 DE→组件关联）统一由 de-session 引入，不在本层列明细。
{ pkgs, user, ... }: {
  imports = [
    ./base.nix                    # 继承 base（mini + apps-extra + rime）
    ./units/apps-im.nix
    ./units/laptop.nix
    ./units/networkmanager.nix
    ./units/walker.nix
  ];

  # ── 通用桌面工具 ─────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    wl-clipboard
  ];
}