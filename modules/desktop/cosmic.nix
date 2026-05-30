{ pkgs, lib, dataDir, ... }:

let
  # 隔离输入法环境变量，防止 cosmic-greeter 尝试激活 fcitx5 导致锁屏卡死
  greeterCmd = "env -u GTK_IM_MODULE -u QT_IM_MODULE -u XMODIFIERS -u INPUT_METHOD -u SDL_IM_MODULE cosmic-greeter";
in {
  # ── COSMIC Desktop Environment ─────────────────────────
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = lib.mkDefault true;

  # 登录/锁屏界面必须绝对干净，禁止加载任何输入法代理，防止密码框卡死
  services.greetd.settings.default_session.command = lib.mkForce greeterCmd;

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