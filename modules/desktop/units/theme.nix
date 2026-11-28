# 桌面主题选择：一个选项决定整套配色（KDE/Qt、Ghostty、Alacritty、herdr、niri 焦点环）。
# 主题数据在 ../assets/themes.nix；本单元只做两件事：
#   1. 声明 config.desktop.theme（枚举 = 数据表里的键）
#   2. 把选中的记录注入 _module.args.theme → 所有模块都能用函数参数 `theme` 取到自己的那一段
# 换主题：host 配置里写 desktop.theme = "gruvbox-light";（或改这里 default）
{ lib, config, ... }:
let
  themes = import ../assets/themes.nix;
in {
  options.desktop.theme = lib.mkOption {
    type = lib.types.enum (builtins.attrNames themes);
    default = "flexoki-light";
    description = ''
      桌面主题名。可选值来自 modules/desktop/assets/themes.nix，
      每套主题自带 KDE 语义色、niri 焦点环、Ghostty 主题名、Alacritty 色表、herdr token。
    '';
  };

  # 注入给其它模块（NixOS 侧用参数 `theme`；HM 侧由 base.nix 桥接一次）
  config._module.args.theme = themes.${config.desktop.theme};
}