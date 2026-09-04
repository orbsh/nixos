# Rime 五笔输入层：wubi86（极简 86 五笔，带拼音反查）。
# 依赖 rime-base（公共 assets 与 schemas 聚合由 base 承载）。
# 主场景「五笔为主、拼音兜底」：wubi86_fg 为纯五笔，wubi86_fg_pinyin
# 为一键切五笔/拼音混合（不索引的字拼音反查）。
# 用 lib.mkBefore 使五笔 schema 排在拼音之前（本机首选五笔）。
{ pkgs, lib, config, user, ... }:
let
  cfg = config.rime.wubi;

  # 五笔词库来源，两种模式：
  # - localPath（本地开发）：mkOutOfStoreSymlink 直连本地 git 仓库文件，
  #   eval 期零 fetch（纯求值合法），改动即时生效。developMode 同款架构。
  # - 远端（默认）：fetchTree 钉住 url+narHash 进 store。
  # 远端 src 有默认值，localPath 有值时优先。
  wubiSrc =
    if cfg.localPath == null then
      (builtins.fetchTree {
        type = "git";
        inherit (cfg.src) url narHash;
      }).outPath
    else null;

  # 五笔相关 schema/dict 文件（含拼音反查依赖）
  files = [
    "wubi86_fg.schema.yaml"
    "wubi86_fg_pinyin.schema.yaml"
    "wubi86_fg_trad.schema.yaml"
    "wubi86_fg_trad_pinyin.schema.yaml"
    "wubi86_fg.dict.yaml"
    "wubi86_fg_addition.dict.yaml"
    "wubi86_fg_user.dict.yaml"
    "pinyin_simp.dict.yaml"
    "pinyin_simp.schema.yaml"
  ];
in {
  imports = [
    ./rime-base.nix
  ];
  options.rime.wubi.enable = lib.mkEnableOption "Rime 五笔输入支持（wubi86，带拼音反查）";

  options.rime.wubi.localPath = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "本地 git 仓库路径（本地模式，无网络依赖）。设置后优先于 src。";
  };

  options.rime.wubi.src = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule {
      options = {
        url = lib.mkOption {
          type = lib.types.str;
          default = "https://github.com/orbsh/rime-wb-fg";
          description = "五笔词库上游 git 仓库地址。";
        };
        narHash = lib.mkOption { type = lib.types.str; };
      };
      # 默认值即上游地址对应的锁定 hash（rev 7323e40）
    });
    default.narHash = "sha256-55yTacvSkt4o+G9QG6YYCnbaOGEcH0e5szDKw9Y7YIY=";
    default.url = "https://github.com/orbsh/rime-wb-fg";
    description = "五笔词库来源（git 仓库 url + narHash）。默认即上游 orbsh/rime-wb-fg 锁定版本；仅 localPath 模式会绕过。";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # 五笔在前：即使与拼音同时启用，wubi schema 也是默认首选
      rime.schemas = lib.mkBefore [
        "wubi86_fg"
        "wubi86_fg_pinyin"
      ];
    })

    # wubi86_fg.custom.yaml / wubi86_fg_pinyin.custom.yaml：四码唯一自动上屏
    (lib.mkIf cfg.enable {
      home-manager.users.${user} = { lib, ... }: {
        xdg.dataFile = {
          "fcitx5/rime/wubi86_fg.custom.yaml".source =
            ../assets/rime/wubi86_fg.custom.yaml;
          "fcitx5/rime/wubi86_fg_pinyin.custom.yaml".source =
            ../assets/rime/wubi86_fg_pinyin.custom.yaml;
        };

        # Nix store 文件 mtime 固定，Rime 可能因此跳过 custom.yaml 重建；
        # 删除已编译 schema，让下一次 Rime 部署强制读取最新补丁。
        home.activation.rimeWubiSchemaRebuild =
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            ${pkgs.coreutils}/bin/rm -f "$HOME/.local/share/fcitx5/rime/build/wubi86_fg.schema.yaml" "$HOME/.local/share/fcitx5/rime/build/wubi86_fg_pinyin.schema.yaml"
          '';
      };
    })

    # 本地模式：symlink 直连本地仓库文件（活文件，改动即时生效）
    # config.lib 在 HM 模块内部作用域才可见，须以内层模块包一层取到
    (lib.mkIf (cfg.enable && cfg.localPath != null) {
      home-manager.users.${user} = { config, ... }: {
        xdg.dataFile = lib.genAttrs (map (f: "fcitx5/rime/${f}") files) (f: {
          # f 含 fcitx5/rime/ 前缀，须剥到文件名再拼 localPath
          source = config.lib.file.mkOutOfStoreSymlink "${cfg.localPath}/${builtins.baseNameOf f}";
        });
      };
    })

    # 远端模式：store 内固定副本（src 默认值 = 上游 orbsh/rime-wb-fg 锁定版本）
    (lib.mkIf (cfg.enable && cfg.localPath == null) {
      home-manager.users.${user}.xdg.dataFile = lib.genAttrs (map (f: "fcitx5/rime/${f}") files) (f: {
        source = "${wubiSrc}/${builtins.baseNameOf f}";
      });
    })
  ];
}