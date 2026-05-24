{ pkgs, lib, dataDir, ... }: {
  # ── COSMIC Desktop Environment ─────────────────────────
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = lib.mkDefault true;

  # ── Pipewire Audio ─────────────────────────────────────
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = true;
  };



  # ── XDG Desktop Portal (COSMIC backend) ────────────────
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-cosmic ];
  };



  # COSMIC DE 已内置 HiDPI 设置界面，无需像 SDDM/Hyprland 那样手动注入 DPI 配置
  # 若需针对 GTK/Qt 应用强制全局缩放，可取消下方注释：
  # environment.sessionVariables = {
  #   GDK_SCALE = "2";
  #   QT_SCALE_FACTOR = "2";
  # };

}