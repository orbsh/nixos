# 编辑器配置：Zed
# 修复在 COSMIC/Wayland 环境下切换虚拟桌面或切屏后输入法（IME）偶尔失灵/假死的问题
{ pkgs, lib, user, ... }:

let
  localPkg = import ../../libs/local-pkg.nix { inherit pkgs user; };
in {
  # ── Zed Overlay：使用 runCommand 复制后包装（避免 symlinkJoin 的符号链接问题） ──────
  nixpkgs.overlays = [
    (final: prev: {
      zed-editor = prev.runCommand "zed-editor-${prev.zed-editor.version}-wrapped" {
        buildInputs = [ prev.makeWrapper ];
      } ''
        cp -r ${prev.zed-editor} $out
        chmod -R u+w $out
        wrapProgram $out/bin/zeditor \
          --set XMODIFIERS "@im=fcitx" \
          --set GTK_IM_MODULE "fcitx" \
          --set QT_IM_MODULE "fcitx"
      '';
    })
  ];

  # ── 编辑器包 ────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    # 如果你使用的是日常稳定版，使用被 Overlay 修正过的包
    zed-editor

    # 临时占位（如果你的 lib/local-pkg 同样需要接管 zed 相关的特殊二进制）
    # (localPkg { pkg = zed-editor; filename = "zed-stable_amd64.deb"; })
  ];

  # ── 系统级 IME 环境变量额外增强 ─────────────────────
  # 当 COSMIC 合成器发生上下文变化时，第二层强力防线
  environment.sessionVariables = {
    XMODIFIERS = "@im=fcitx";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
  };
}
