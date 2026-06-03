{ pkgs, lib, config, ... }:

{
  options.desktop.vivaldi = {
    src = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          url = lib.mkOption { type = lib.types.str; };
          narHash = lib.mkOption { type = lib.types.str; };
        };
      });
      default = null;
      description = "Vivaldi 安装包来源（指定 url 和 narHash）。非空时覆盖 nixpkgs 默认版本。";
    };
  };

  config = let
    cfg = config.desktop.vivaldi;
    srcPath = if cfg.src != null
      then (builtins.fetchTree {
        type = "file";
        inherit (cfg.src) url narHash;
      }).outPath
      else null;
  in {
    # ── Vivaldi Overlay：修复 COSMIC 200% 缩放下界面放大 ──
    nixpkgs.overlays = [
      (final: prev: let
        vivaldiBase =
          if srcPath != null
          then prev.vivaldi.overrideAttrs (old: {
            src = srcPath;
          })
          else prev.vivaldi;
      in {
        vivaldi = vivaldiBase.override {
          commandLineArgs = "--enable-features=UseOzonePlatform --ozone-platform=wayland --disable-features=WaylandPerSurfaceScale --force-device-scale-factor=1 --enable-wayland-ime";
        };
      })
    ];

    # ── 浏览器包 ────────────────────────────────────────
    environment.systemPackages = with pkgs; [
      vivaldi
    ];

    # ── Chromium 内核全局配置 ───────────────────────────
    # 强制 Wayland 原生渲染 + 固定 1:1 像素缩放
    nixpkgs.config.chromium.commandLineArgs = "--enable-features=UseOzonePlatform --ozone-platform=wayland --force-device-scale-factor=1";

    # ── 允许非自由包 ────────────────────────────────────
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (pkg.pname or "") [
        "vivaldi"
      ];
  };
}
