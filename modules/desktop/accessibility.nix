{ pkgs, lib, ... }:

{
  # 1. 彻底禁用 GNOME/COSMIC 桌面框架的无障碍底层总线（打字播报的罪魁祸首）
  services.gnome.at-spi2-core.enable = lib.mkForce false;

  # 2. 强行在全局环境变量中，对所有软件关闭无障碍辅助功能检测
  environment.sessionVariables = {
    ACCESSIBILITY_ENABLED = "0";
    GNOME_ACCESSIBILITY = "0";
    NO_AT_BRIDGE = "1"; # 强制切断 Gtk/Qt 软件向语音引擎发送打字文本的桥梁
  };

  # 3. 强行下线系统级的语音合成守护进程（让系统丧失说话能力）
  systemd.user.services.mute-speech-dispatcher = {
    description = "Kill and mask speech-dispatcher to stop typing voice broadcast";
    wantedBy = [ "graphical-session.target" ];
    script = ''
      # 登录桌面瞬间，立刻终止所有语音播报服务，并阻止其再次苏醒
      ${pkgs.procps}/bin/pkill -f speech-dispatcher || true
      ${pkgs.procps}/bin/pkill -f orca || true
    '';
  };
}
