# Rime 输入法公共基础层（rime-pinyin / rime-wubi 共用）。
# 职责：公共 assets（主题/后端 conf/默认配置/rime.lua）+ 方案聚合选项。
# 不做任何具体输入方案部署——那属于 pinyin / wubi 模块。
# fcitx5-rime 后端启用由 input-method.nix（系统级）承担，不在本模块。
{ pkgs, lib, config, user, ... }:
let
  cfg = config.rime;
in {
  options.rime.schemas = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      启用的 rime 输入方案（schema 名，按序为默认切换顺序）。
      由各方案模块(rime-pinyin / rime-wubi)注册，base 聚合成 default.custom.yaml 的 schema_list。
    '';
  };

  config = lib.mkMerge [
    # ── Home Manager 用户配置：公共 assets ──
    {
      home-manager.users.${user} = {
        # default.yaml：基础全局配置（无 schema_list，见 assets 注释）
        xdg.dataFile."fcitx5/rime/default.yaml".source = ../assets/rime/default.yaml;
        # rime.lua：公共 lua 脚本
        xdg.dataFile."fcitx5/rime/rime.lua".source = ../assets/rime/rime.lua;

        # 方案聚合：schema_list 由各方案模块注册的 schemas 生成
        # 用 concatStrings 显式构造（不依赖 heredoc 缩进剥离，确定性最高）
        xdg.dataFile."fcitx5/rime/default.custom.yaml".text = lib.concatStrings [
          "patch:\n"
          "  schema_list:\n"
          (lib.concatMapStringsSep "\n" (s: "    - schema: ${s}") cfg.schemas)
          "\n"
        ];
      };
    }

    # ── Fcitx5 ClassicUI 候选窗主题（白底 + 深棕字, accent #dea584）──
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

        # Rime 后端配置：中英状态跨程序独立（InputState=Program）
        # force=true：此前是手放普通文件（由 All 改为 Program），HM 需覆盖。
        xdg.configFile."fcitx5/conf/rime.conf" = {
          source = ../assets/rime/rime.conf;
          force = true;
        };
      };
    }
  ];
}