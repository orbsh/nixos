# qutebrowser: Wayland 原生（已弃用 2026-11-12）
# 弃用原因：nixpkgs 把 qutebrowser-3.7.0 标记为 insecure（eMudhra 中间证书私钥可恢复，
# QtWebEngine 从不检查 CRLset 吊销），eval 阶段直接拒绝构建；换用 vivaldi（默认浏览器）。
# 保留本文件备查：恢复时把 mini.nix 的 imports 加回，并按需放行 insecure 包。
#
# 原始说明：修复在 COSMIC/Wayland 下访问特定站点时画面狂闪、切走残留元素的问题
# （裸包会因 XWayland 存在而默认走 xcb，主窗口与 QtWebEngine 子窗口合成不一致导致残影闪烁）
{ pkgs, lib, user, ... }:

let
  qutebrowser-wayland = pkgs.symlinkJoin {
    name = "qutebrowser-wayland";
    paths = [ pkgs.qutebrowser ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/qutebrowser \
        --set QT_QPA_PLATFORM wayland \
        --set QTWEBENGINE_CHROMIUM_FLAGS '--disable-accelerated-video-decode'

      # 覆盖 desktop entry，指向 wrapped binary
      rm -f $out/share/applications/org.qutebrowser.qutebrowser.desktop
      mkdir -p $out/share/applications
      cat > $out/share/applications/org.qutebrowser.qutebrowser.desktop << DESKTOP
[Desktop Entry]
Name=qutebrowser
GenericName=Web browser
GenericName[zh_CN]=网页浏览器
Comment=qutebrowser is a keyboard-driven, vim-like browser based on QtWebEngine.
Comment[zh_CN]=基于 QtWebEngine 的 vim 风格键盘驱动浏览器
Exec=$out/bin/qutebrowser %F
Icon=qutebrowser
StartupNotify=true
Terminal=false
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
DESKTOP
    '';
  };
in {
  # ── qutebrowser 包 ──────────────────────────────────────
  environment.systemPackages = [
    qutebrowser-wayland
  ];

  # ── qutebrowser 配置文件 ──────────────────────────────────
  home-manager.users.${user} = {
    xdg.configFile."qutebrowser/config.py".source = ../../desktop/assets/qutebrowser/config.py;
    xdg.configFile."qutebrowser/userscripts".source = ../../desktop/assets/qutebrowser/userscripts;
  };
}
