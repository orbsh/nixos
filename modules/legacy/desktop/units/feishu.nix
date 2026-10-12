{ pkgs, lib, config, ... }:

{
  options.desktop.feishu = {
    src = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          url = lib.mkOption { type = lib.types.str; };
          narHash = lib.mkOption { type = lib.types.str; };
        };
      });
      default = null;
      description = "飞书安装包来源（指定 url 和 narHash）。非空时覆盖 nixpkgs 默认版本。";
    };
  };

  config = let
    cfg = config.desktop.feishu;
    srcPath = if cfg.src != null
      then (builtins.fetchTree {
        type = "file";
        inherit (cfg.src) url narHash;
      }).outPath
      else null;
  in {
    # ── 飞书 Overlay：Wayland 原生 + fcitx5 候选框 ──
    nixpkgs.overlays = [
      (final: prev: let
        feishuBase =
          if srcPath != null
          then prev.feishu.overrideAttrs (old: {
            src = srcPath;
            version = "custom";
          })
          else prev.feishu;

        # 飞书：Wayland 原生 + fcitx5 候选框
        feishu-wayland = final.symlinkJoin {
          name = "feishu-wayland";
          paths = [ feishuBase ];
          buildInputs = [ final.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/bytedance-feishu \
              --add-flags "--ozone-platform=wayland" \
              --add-flags "--enable-wayland-ime"

            # 覆盖 desktop entry，指向 wrapped binary
            rm -f $out/share/applications/bytedance-feishu.desktop
            mkdir -p $out/share/applications
            cat > $out/share/applications/bytedance-feishu.desktop << EOF
[Desktop Entry]
Version=1.0
Name=Feishu
Name[zh_CN]=飞书
GenericName=Feishu
GenericName[zh_CN]=飞书
Comment=Feishu is an all-in-one platform that integrates instant communication, calendar, video meeting, collaborative documents, workplace, and various features. Feishu aims to make your work more enjoyable and achieve more efficient teamwork.
Comment[zh_CN]=飞书整合即时消息、日历、音视频会议、云文档、工作台等功能于一体，成就团队和个人，更高效、更愉悦。
Exec=$out/bin/bytedance-feishu %U
StartupNotify=true
Terminal=false
Icon=bytedance-feishu
Type=Application
Categories=Office;
MimeType=message/rfc822;x-scheme-handler/feishu;x-scheme-handler/feishu-open;x-scheme-handler/lark;x-scheme-handler/x-feishu;
EOF
          '';
        };
      in {
        feishu = feishuBase;
        feishu-wayland = feishu-wayland;
      })
    ];

    # ── 飞书包 ────────────────────────────────────────
    environment.systemPackages = [
      pkgs.feishu-wayland
    ];

    # ── 允许非自由包 ────────────────────────────────────
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (pkg.pname or "") [
        "feishu"
      ];
  };
}
