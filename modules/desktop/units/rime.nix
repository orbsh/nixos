{ pkgs, lib, dataDir, config, user, ... }:
let
  rimeIce = pkgs.rime-ice;
  cfg = config.rime.wubi;
  octCfg = config.rime.octagram;
  wanxiangCfg = config.rime.wanxiang;

  # 五笔词库来源：fetchTree 钉住 url+narHash（同 wanxiang），不再走 dataDir 外部路径。
  # src 为空时 wubiSrc = null，且下方五笔块 gated 在 enable && src!=null，不会触发 fetch。
  wubiSrc = if cfg.src != null then (builtins.fetchTree {
    type = "git";
    inherit (cfg.src) url narHash;
  }).outPath else null;

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
  # ── Rime 输入法配置（雾凇拼音 + 小鹤双拼 + 可选五笔/八股文）───

  options.rime.wubi.enable = lib.mkEnableOption "Rime 五笔输入支持";

  options.rime.wubi.src = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule {
      options = {
        url = lib.mkOption { type = lib.types.str; };
        narHash = lib.mkOption { type = lib.types.str; };
      };
    });
    default = null;
    description = "五笔词库来源（storage git 仓库 url + narHash，与 wanxiang 同机制）。为空时不启用五笔词库。";
  };

  options.rime.octagram.enable = lib.mkEnableOption "Rime Octagram N-Gram 语言模型（提升长句预测准确度）";

  options.rime.wanxiang = {
    src = lib.mkOption {
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
    {
      # ── Octagram overlay：关闭合并编译，生成独立 .so ──
      nixpkgs.overlays = lib.mkIf octCfg.enable [
        # BUILD_MERGED_PLUGINS=ON (default): plugins compiled into librime.so,
        # avoiding runtime dlopen issues with fcitx5-rime
      ];
    }

    # ── Home Manager 用户配置 ──
    {
      home-manager.users.${user} = {
        # ── Custom default.yaml ──
        xdg.dataFile."fcitx5/rime/default.yaml".source = ../assets/rime/default.yaml;
        # ── Custom rime.lua ──
        xdg.dataFile."fcitx5/rime/rime.lua".source = ../assets/rime/rime.lua;
      };
    }

    # Generate xdg.dataFile entries for all rime-ice files
    {
      home-manager.users.${user}.xdg.dataFile = lib.genAttrs (map (f: "fcitx5/rime/${f}") rimeIceFiles) (f: {
        source = "${rimeIce}/share/rime-data/${builtins.baseNameOf f}";
      });
    }

    # Generate xdg.dataFile entries for all rime-ice directories
    {
      home-manager.users.${user}.xdg.dataFile = lib.genAttrs (map (d: "fcitx5/rime/${d}") rimeIceDirs) (d: {
        source = "${rimeIce}/share/rime-data/${builtins.baseNameOf d}";
      });
    }

    # librime-lua and librime-octagram are merged into librime.so at build time
    # (BUILD_MERGED_PLUGINS=ON), no runtime plugin deployment needed

    (lib.mkIf (cfg.enable && wubiSrc != null) {
      home-manager.users.${user} = {
        # ── Wubi overlay files ──
        xdg.dataFile."fcitx5/rime/wubi86_fg.schema.yaml".source = "${wubiSrc}/wubi86_fg.schema.yaml";
        xdg.dataFile."fcitx5/rime/wubi86_fg_pinyin.schema.yaml".source = "${wubiSrc}/wubi86_fg_pinyin.schema.yaml";
        xdg.dataFile."fcitx5/rime/wubi86_fg_trad.schema.yaml".source = "${wubiSrc}/wubi86_fg_trad.schema.yaml";
        xdg.dataFile."fcitx5/rime/wubi86_fg_trad_pinyin.schema.yaml".source = "${wubiSrc}/wubi86_fg_trad_pinyin.schema.yaml";

        xdg.dataFile."fcitx5/rime/wubi86_fg.dict.yaml".source = "${wubiSrc}/wubi86_fg.dict.yaml";
        xdg.dataFile."fcitx5/rime/wubi86_fg_addition.dict.yaml".source = "${wubiSrc}/wubi86_fg_addition.dict.yaml";
        xdg.dataFile."fcitx5/rime/wubi86_fg_user.dict.yaml".source = "${wubiSrc}/wubi86_fg_user.dict.yaml";
        xdg.dataFile."fcitx5/rime/pinyin_simp.dict.yaml".source = "${wubiSrc}/pinyin_simp.dict.yaml";
        xdg.dataFile."fcitx5/rime/pinyin_simp.schema.yaml".source = "${wubiSrc}/pinyin_simp.schema.yaml";
      };
    })

    (lib.mkIf octCfg.enable {
      # librime-octagram is merged into librime.so at build time
    })

    (lib.mkIf (octCfg.enable && wanxiangModel != null) {
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

    # ── Fcitx5 ClassicUI 候选窗主题（白底 + 深棕字，accent #dea584）──
    {
      home-manager.users.${user} = {
        # 候选窗主题 theme.conf + 翻页/勾选影像
        # force=true：这些文件此前是手放普通文件，HM 需要覆盖。内容与 assets 一致（幂等）。
        xdg.dataFile."fcitx5/themes/niri/theme.conf" = {
          source = ../assets/rime/theme.conf;
          force = true;
        };
        xdg.dataFile."fcitx5/themes/niri/prev.png" = {
          source = ../assets/rime/prev.png;
          force = true;
        };
        xdg.dataFile."fcitx5/themes/niri/next.png" = {
          source = ../assets/rime/next.png;
          force = true;
        };
        xdg.dataFile."fcitx5/themes/niri/radio.png" = {
          source = ../assets/rime/radio.png;
          force = true;
        };
        xdg.dataFile."fcitx5/themes/niri/arrow.png" = {
          source = ../assets/rime/arrow.png;
          force = true;
        };

        # ClassicUI 配置（扁平格式；无 [ClassicUI] 段头——带段头整段不生效）
        xdg.configFile."fcitx5/conf/classicui.conf" = {
          source = ../assets/rime/classicui.conf;
          force = true;
        };
      };
    }
  ];
}
