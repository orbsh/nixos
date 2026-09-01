# Rime 拼音输入层：rime-ice（雾凇拼音 + 小鹤双拼）+ 可选语言模型。
# 依赖 rime-base（公共 assets 与 schemas 聚合由 base 承载）。
# 默认注册 rime_ice + double_pinyin_flypy 两个 schema。
{ pkgs, lib, config, user, ... }:
let
  rimeIce = pkgs.rime-ice;
  cfg = config.rime.pinyin;
  octCfg = config.rime.pinyin.octagram;
  wanxiangCfg = config.rime.pinyin.wanxiang;

  wanxiangSrcPath = if wanxiangCfg.src != null then
    (builtins.fetchTree {
      type = "file";
      inherit (wanxiangCfg.src) url narHash;
    }).outPath
  else null;

  wanxiangModel = wanxiangSrcPath;

  # Enumerate all rime-ice files and directories
  rimeIceFiles = [
    # Top-level schema/dict files
    "custom_phrase.txt"
    "double_pinyin.schema.yaml"
    "double_pinyin_abc.schema.yaml"
    "double_pinyin_flypy.schema.yaml"
    "double_pinyin_jiajia.schema.yaml"
    "double_pinyin_mspy.schema.yaml"
    "double_pinyin_sogou.schema.yaml"
    "double_pinyin_ziguang.schema.yaml"
    "go.work"
    "melt_eng.dict.yaml"
    "melt_eng.schema.yaml"
    "radical_pinyin.dict.yaml"
    "radical_pinyin.schema.yaml"
    "rime_ice.dict.yaml"
    "rime_ice.schema.yaml"
    "rime_ice_suggestion.yaml"
    "squirrel.yaml"
    "symbols_caps_v.yaml"
    "symbols_v.yaml"
    "t9.schema.yaml"
    "weasel.yaml"
  ];
  rimeIceDirs = [ "cn_dicts" "en_dicts" "lua" "opencc" ];
in {
  imports = [
    ./rime-base.nix
  ];
  options.rime.pinyin = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Rime 拼音输入支持（rime-ice 雾凇 + 小鹤双拼）。默认启用（保持旧 rime.nix 无条件部署拼音的行为）。";
    };

    octagram.enable = lib.mkEnableOption "Rime Octagram N-Gram 语言模型（提升长句预测准确度）";

    wanxiang.src = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          url = lib.mkOption { type = lib.types.str; };
          narHash = lib.mkOption { type = lib.types.str; };
        };
      });
      default = null;
      description = "万象模型来源（指定 url 和 narHash）。为空时不启用万象模型。";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home-manager.users.${user}.xdg.dataFile = lib.mkMerge [
        # rime-ice files
        (lib.genAttrs (map (f: "fcitx5/rime/${f}") rimeIceFiles) (f: {
          source = "${rimeIce}/share/rime-data/${builtins.baseNameOf f}";
        }))
        # rime-ice directories
        (lib.genAttrs (map (d: "fcitx5/rime/${d}") rimeIceDirs) (d: {
          source = "${rimeIce}/share/rime-data/${builtins.baseNameOf d}";
        }))
      ];
      # 拼音方案：雾凇 + 小鹤双拼
      rime.schemas = [ "rime_ice" "double_pinyin_flypy" ];
    })

    (lib.mkIf (cfg.enable && octCfg.enable && wanxiangModel != null) {
      home-manager.users.${user} = {
        # ── 万象八股文语法模型 ──
        xdg.dataFile."fcitx5/rime/wanxiang-lts-zh-hans.gram".source = wanxiangModel;

        # octagram.yaml — only patches grammar, NOT translator
        # (translator patches replace the whole section instead of merging)
        xdg.dataFile."fcitx5/rime/octagram.yaml".text = ''
          octagram:
            __patch:
              grammar:
                language: wanxiang-lts-zh-hans
                collocation_max_length: 8
                collocation_min_length: 2
                collocation_penalty: -15
                non_collocation_penalty: -5
                weak_collocation_penalty: -100
                rear_penalty: -10
        '';

        # 雾凇拼音方案 — only apply grammar patch, preserve schema's translator config
        xdg.dataFile."fcitx5/rime/rime_ice.custom.yaml".text = ''
          patch:
            __include: octagram:/octagram
        '';

        # 小鹤双拼方案 — only apply grammar patch, preserve schema's translator config
        xdg.dataFile."fcitx5/rime/double_pinyin_flypy.custom.yaml".text = ''
          patch:
            __include: octagram:/octagram
        '';
      };
    })
  ];
}