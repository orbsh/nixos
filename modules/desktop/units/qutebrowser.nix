{ pkgs, lib, user, ... }:

let
  # X11 模式：c.window.hide_decoration 在 Wayland/COSMIC 下无效
  qutebrowser-xcb = pkgs.symlinkJoin {
    name = "qutebrowser-xcb";
    paths = [ pkgs.qutebrowser ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/qutebrowser \
        --set QT_QPA_PLATFORM xcb
    '';
  };
in {
  # ── qutebrowser 包 ──────────────────────────────────────
  environment.systemPackages = [
    qutebrowser-xcb
  ];

  # ── qutebrowser 配置文件 ──────────────────────────────────
  home-manager.users.${user} = {
    xdg.configFile."qutebrowser/config.py".source = ../assets/qutebrowser/config.py;
    xdg.configFile."qutebrowser/userscripts".source = ../assets/qutebrowser/userscripts;
  };
}
