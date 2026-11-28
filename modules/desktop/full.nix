# 桌面预设 · full（满配工作站）
# = standard + apps-im + laptop + networkmanager + mudra
# walker 已于 2026-11-28 退出活跃树：启动器改用 Noctalia 内置 launcher，
# 原模块与资产移到 modules/legacy/desktop/{units/walker.nix,assets/{walker,elephant}}（保留不删）。
# 桌面子系统（cosmic/hyprland/quickshell/eww 及 DE→组件关联）统一由 de-session 引入，不在本层列明细。
{ pkgs, user, ... }: {
  imports = [
    ./standard.nix                # 继承 standard（base + apps-extra + rime）
    ./units/apps-im.nix
    ./units/laptop.nix
    ./units/networkmanager.nix
    # ../legacy/desktop/units/walker.nix   # 已移入 legacy（启动器改 Noctalia）
    ./units/mudra.nix
  ];

  # ── 可移动设备 ───────────────────────────────────────────
  # udisks2 提供 org.freedesktop.UDisks2：文件管理器（Dolphin 等）经它挂载 U 盘/移动硬盘，
  # 授权走 modules/system/units/sys.nix 已启用的 polkit。udisks2 只做按需挂载，
  # 插入不会自动挂到 /run/media（要自动挂需再加 udiskie）。
  services.udisks2.enable = true;

  # ── 通用桌面工具 ─────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    wl-clipboard
  ];
}