{ pkgs, lib, dataDir, config, ... }:
let
  rimeIce = pkgs.rime-ice;
  wubiSrc = "${dataDir}/rime-wubi";
  cfg = config.rime.wubi;

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
  # ── Rime 输入法配置（雾凇拼音 + 小鹤双拼 + 可选五笔）───

  options.rime.wubi.enable = lib.mkEnableOption "Rime 五笔输入支持";

  config = lib.mkMerge [
    {
      # ── Custom default.yaml (our schema_list + key bindings) ──
      xdg.dataFile."fcitx5/rime/default.yaml".text = ''
        config_version: '2026-02-06'

        schema_list:
          - schema: rime_ice
          - schema: double_pinyin_flypy
        '' + lib.optionalString cfg.enable ''
          - schema: wubi86_fg
          - schema: wubi86_fg_pinyin
          - schema: wubi86_fg_trad
          - schema: wubi86_fg_trad_pinyin
        '' + ''
        menu:
          page_size: 5

        switcher:
          caption: 〔方案选单〕
          hotkeys:
            - F4
            - Control+grave
            - Control+Shift+grave
          save_options:
            - ascii_punct
            - traditionalization
            - emoji
            - full_shape
            - search_single_char
          fold_options: true
          abbreviate_options: true
          option_list_separator: ' / '

        ascii_composer:
          good_old_caps_lock: true
          switch_key:
            Caps_Lock: clear
            Shift_L: commit_code
            Shift_R: noop
            Control_L: noop
            Control_R: noop

        punctuator:
          digit_separators: ",.:"
          full_shape:
            ' ' : { commit: ' ' }
            ',' : { commit: ， }
            '.' : { commit: 。 }
            '<' : [ 《, 〈, «, ‹ ]
            '>' : [ 》, 〉, », › ]
            '/' : [ ／, ÷ ]
            '?' : { commit: ？ }
            ";" : { commit: ； }
            ":" : { commit: ： }
            "'" : { pair: [ "'", "'" ] }
            '"' : { pair: [ '"', '"' ] }
            '\' : [ 、, ＼ ]
            '|' : [ ·, ｜, '§', '¦' ]
            '`' : ｀
            '~' : ～
            '!' : { commit: ！ }
            '@' : [ ＠, ☯ ]
            '#' : [ ＃, ⌘ ]
            '%' : [ ％, '°', '℃' ]
            '$' : [ ￥, '$', '€', '£', '¥', '¢', '¤' ]
            '^' : { commit: …… }
            '&' : ＆
            '*' : [ ＊, ·, ・, ×, ※, ❂ ]
            '(' : （
            ')' : ）
            '-' : －
            '_' : ——
            '+' : ＋
            '=' : ＝
            '[' : [ 「, 【, 〔, ［ ]
            ']' : [ 」, 】, 〕, ］ ]
            '{' : [ 『, 〖, ｛ ]
            '}' : [ 』, 〗, ｝ ]
          half_shape:
            ',' : '，'
            '.' : '。'
            '<' : '《'
            '>' : '》'
            '/' : '/'
            '?' : '？'
            ";" : '；'
            ":" : '：'
            "'" : { pair: [ "'", "'" ] }
            '"' : { pair: [ '"', '"' ] }
            '\' : '、'
            '|' : '|'
            '`' : '·'
            '~' : '~'
            '!' : '！'
            '@' : '@'
            '#' : '#'
            '%' : '%'
            '$' : '¥'
            '^' : '……'
            '&' : '&'
            '*' : '*'
            '(' : '（'
            ')' : '）'
            '-' : '-'
            '_' : ——
            '+' : '+'
            '=' : '='
            '[' : '【'
            ']' : '】'
            '{' : '「'
            '}' : '」'

        recognizer:
          patterns:
            email: "^[a-z][-_.0-9a-z]*@.*$"
            uppercase: "[A-Z][-_+.'0-9A-Za-z]*$"
            url: "^(www[.]|https?:|ftp:|mailto:).*$|^[0-9a-z]+[-_.0-9a-z]*\\.[a-z]+$"

        key_binder:
          bindings:
            - {accept: "Control+Shift+1", toggle: ascii_mode, when: always}
            - {accept: "Control+Shift+2", toggle: full_shape, when: always}
            - {accept: "Control+Shift+e", toggle: simplified, when: always}
            - {accept: "Control+Shift+3", toggle: traditionalization, when: always}
            - {accept: "Control+Shift+4", toggle: ascii_punct, when: always}
            - {accept: bracketleft, send: Page_Up, when: paging}
            - {accept: bracketright, send: Page_Down, when: has_menu}
            - {accept: minus, send: Page_Up, when: paging}
            - {accept: equal, send: Page_Down, when: has_menu}
            - {accept: comma, send: comma, when: has_menu}
            - {accept: period, send: period, when: has_menu}
            - {accept: semicolon, send: semicolon, when: has_menu}
            - {accept: apostrophe, send: apostrophe, when: has_menu}
      '';

      # ── Custom rime.lua ──
      xdg.dataFile."fcitx5/rime/rime.lua".source = ../../data/rime-lua/rime.lua;

      # ── ALL rime-ice files (individual symlinks → writable parent dir) ──
    }

    # Generate xdg.dataFile entries for all rime-ice files
    { xdg.dataFile = lib.genAttrs (map (f: "fcitx5/rime/${f}") rimeIceFiles) (f: {
      source = "${rimeIce}/share/rime-data/${builtins.baseNameOf f}";
    }); }

    # Generate xdg.dataFile entries for all rime-ice directories
    { xdg.dataFile = lib.genAttrs (map (d: "fcitx5/rime/${d}") rimeIceDirs) (d: {
      source = "${rimeIce}/share/rime-data/${builtins.baseNameOf d}";
    }); }

    (lib.mkIf cfg.enable {
      # ── Wubi overlay files ────────────────────────
      xdg.dataFile."fcitx5/rime/wubi86_fg.schema.yaml".source = "${wubiSrc}/wubi86_fg.schema.yaml";
      xdg.dataFile."fcitx5/rime/wubi86_fg_pinyin.schema.yaml".source = "${wubiSrc}/wubi86_fg_pinyin.schema.yaml";
      xdg.dataFile."fcitx5/rime/wubi86_fg_trad.schema.yaml".source = "${wubiSrc}/wubi86_fg_trad.schema.yaml";
      xdg.dataFile."fcitx5/rime/wubi86_fg_trad_pinyin.schema.yaml".source = "${wubiSrc}/wubi86_fg_trad_pinyin.schema.yaml";

      xdg.dataFile."fcitx5/rime/wubi86_fg.dict.yaml".source = "${wubiSrc}/wubi86_fg.dict.yaml";
      xdg.dataFile."fcitx5/rime/wubi86_fg_addition.dict.yaml".source = "${wubiSrc}/wubi86_fg_addition.dict.yaml";
      xdg.dataFile."fcitx5/rime/wubi86_fg_user.dict.yaml".source = "${wubiSrc}/wubi86_fg_user.dict.yaml";
      xdg.dataFile."fcitx5/rime/pinyin_simp.dict.yaml".source = "${wubiSrc}/pinyin_simp.dict.yaml";
      xdg.dataFile."fcitx5/rime/pinyin_simp.schema.yaml".source = "${wubiSrc}/pinyin_simp.schema.yaml";
    })
  ];
}
