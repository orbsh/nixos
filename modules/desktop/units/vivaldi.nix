{ pkgs, lib, config, ... }:

{
  options.desktop.vivaldi = {
    src = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Vivaldi 安装包源路径（通过 `nix store add-file` 添加后填入）。非空时覆盖 nixpkgs 默认版本。";
    };
  };

  config = let
    cfg = config.desktop.vivaldi;
  in {
    # ── Vivaldi Overlay：修复 COSMIC 200% 缩放下界面放大 ──
    nixpkgs.overlays = [
      (final: prev: let
        vivaldiBase =
          if cfg.src != null
          then prev.vivaldi.overrideAttrs (old: {
            src = cfg.src;
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
