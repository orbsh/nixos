# 浏览器配置：Vivaldi + Chromium
# --disable-features=WaylandPerSurfaceScale 切断 Chromium 与 compositor 的重复缩放计算
# --enable-wayland-ime 开启 Wayland 原生输入法文本协议
{ pkgs, lib, user, ... }:

let
  localPkg = import ../../libs/local-pkg.nix { inherit pkgs user; };
in {
  # ── Vivaldi Overlay：修复 COSMIC 200% 缩放下界面放大 ──
  nixpkgs.overlays = [
    (final: prev: {
      vivaldi = prev.vivaldi.override {
        commandLineArgs = "--enable-features=UseOzonePlatform --ozone-platform=wayland --disable-features=WaylandPerSurfaceScale --force-device-scale-factor=1 --enable-wayland-ime";
      };
    })
  ];

  # ── 浏览器包 ────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    (localPkg { pkg = vivaldi; filename = "vivaldi-stable_8.0.4033.35-1_amd64.deb"; })
  ];

  # ── Chromium 内核全局配置 ───────────────────────────
  # 强制 Wayland 原生渲染 + 固定 1:1 像素缩放
  nixpkgs.config.chromium.commandLineArgs = "--enable-features=UseOzonePlatform --ozone-platform=wayland --force-device-scale-factor=1";

  # ── 允许非自由包 ────────────────────────────────────
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkg.pname or "") [
      "vivaldi"
    ];
}
