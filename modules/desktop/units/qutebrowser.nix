{ pkgs, lib, user, ... }:

let
  # 强制 Wayland 原生 + 禁用窗口装饰（标题栏）
  qutebrowser-wayland = pkgs.symlinkJoin {
    name = "qutebrowser-wayland";
    paths = [ pkgs.qutebrowser ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/qutebrowser \
        --set QT_QPA_PLATFORM wayland \
        --set QT_WAYLAND_DISABLE_WINDOWDECORATION 1
    '';
  };
in {
  # ── qutebrowser 包 ──────────────────────────────────────
  environment.systemPackages = [
    qutebrowser-wayland
  ];

  # ── qutebrowser 配置文件 ──────────────────────────────────
  home-manager.users.${user} = {
    xdg.configFile."qutebrowser/config.py".source = ../assets/qutebrowser/config.py;
    xdg.configFile."qutebrowser/userscripts".source = ../assets/qutebrowser/userscripts;
  };
}
