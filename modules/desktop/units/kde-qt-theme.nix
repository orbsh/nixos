# KDE/Qt 主题单元：Dolphin 等 Qt/KDE 应用跟随 config.desktop.theme。
# 配色数据在 assets/themes.nix，本单元只负责把 theme.kde 落成两个用户文件：
#   ~/.local/share/color-schemes/<scheme>.colors  KDE 语义色（视图底/交替行/选中/焦点）
#   ~/.config/kdeglobals                          选方案 + 控件风格 + 图标主题
# 链路：plasma-integration 提供 kde 平台主题（Qt 应用从 kdeglobals 取调色板/字体/图标），
#       breeze 提供控件风格插件。
# 不用 Kvantum：它的皮肤只能整套换（nixpkgs 只有 gruvbox 的），底色写死在 svg 里，
# 配色文件管不到；Breeze 的控件色则由配色文件统一驱动，换主题不用换皮肤。
{ pkgs, lib, user, theme, ... }:
let
  # 主题表里是 #RRGGBB，KDE ColorScheme 要 "r,g,b"
  rgb = hex:
    let
      h = lib.fromHexString (lib.removePrefix "#" hex);
      r = h / 65536;
      g = (h - r * 65536) / 256;
      b = h - (h / 256) * 256;
    in "${toString r},${toString g},${toString b}";

  palette = lib.mapAttrs (_: rgb) theme.kde.palette;

  # 每个 Colors:* 段共用的 12 个键（KDE 语义色标准集合，缺键会回落到 Breeze 默认色）
  colorSet = bg: bgAlt: fg: fgInactive: lib.concatStrings [
    "BackgroundAlternate=${bgAlt}\n"
    "BackgroundNormal=${bg}\n"
    "DecorationFocus=${palette.focus}\n"
    "DecorationHover=${palette.hover}\n"
    "ForegroundActive=${palette.focus}\n"
    "ForegroundInactive=${fgInactive}\n"
    "ForegroundLink=${palette.blue}\n"
    "ForegroundNegative=${palette.red}\n"
    "ForegroundNeutral=${palette.yellow}\n"
    "ForegroundNormal=${fg}\n"
    "ForegroundPositive=${palette.green}\n"
    "ForegroundVisited=${palette.purple}\n"
  ];

  section = name: body: "[Colors:${name}]\n${body}\n";

  colorScheme = lib.concatStrings [
    "[General]\n"
    "ColorScheme=${theme.kde.scheme}\n"
    "Name=${theme.label}\n"
    "\n"

    (section "Window" (colorSet palette.bg palette.bgAlt palette.fg palette.fgInactive))
    (section "View" (colorSet palette.bg palette.bgAlt palette.fg palette.fgInactive))
    (section "Button" (colorSet palette.bgButton palette.bgButtonAlt palette.fg palette.fgInactive))
    (section "Selection" (colorSet palette.bgSelection palette.bgSelectionAlt palette.fgSelection palette.fgInactiveSel))
    (section "Tooltip" (colorSet palette.bgTooltip palette.bgAlt palette.fg palette.fgInactive))
    (section "Complementary" (colorSet palette.bgButtonAlt palette.bgSelectionAlt palette.fgSelection palette.fgInactive))
    (section "Header" (colorSet palette.bgButton palette.bgButtonAlt palette.fg palette.fgInactive))

    # 窗口装饰色（niri 不管这套；留给 kwin/aurorae 类场景，保持色板完整）
    "[WM]\n"
    "activeBackground=${palette.bgButton}\n"
    "activeBlend=${palette.bgButtonAlt}\n"
    "activeForeground=${palette.fg}\n"
    "inactiveBackground=${palette.bgAlt}\n"
    "inactiveBlend=${palette.bgAlt}\n"
    "inactiveForeground=${palette.fgInactive}\n"
    "frame=${palette.bgButton}\n"
  ];

  qtPluginPrefix = pkgs.qt6.qtbase.qtPluginPrefix;
in {
  # ── 系统级：Qt 平台主题 + Breeze 控件插件 ──
  # 只要 lib/qt-6/plugins（NixOS 的 system-path 会链 /lib）
  environment.systemPackages = [
    pkgs.kdePackages.plasma-integration
    pkgs.kdePackages.breeze
  ];

  # 不用 qt.enable：它会连带装 kdePackages.systemsettings + kio（整套 Plasma 设置面板，
  # 在 niri 里没用），而插件路径这里只需两条。
  # 用 environment.variables（fcitx5 模块也在这里放 QT_PLUGIN_PATH）：列表形式由该选项的
  # apply 按 ":" 拼接；改用 sessionVariables 会因为「列表 vs 已拼接字符串」两个定义撞类型。
  environment.variables = {
    QT_QPA_PLATFORMTHEME = "kde";
    QT_STYLE_OVERRIDE = "breeze";
    # systemPackages 里的 Qt 插件不会自动进 QT_PLUGIN_PATH；与 fcitx5 的条目合并成一条
    QT_PLUGIN_PATH = [
      "${pkgs.kdePackages.plasma-integration}/${qtPluginPrefix}"
      "${pkgs.kdePackages.breeze}/${qtPluginPrefix}"
    ];
  };

  # ── 用户级：配色方案 + kdeglobals ──
  home-manager.users.${user} = {
    xdg.dataFile."color-schemes/${theme.kde.scheme}.colors".text = colorScheme;

    # force：现存 ~/.config/kdeglobals 是 KDE 应用自写的普通文件，HM 需要接管。
    # 接管后该文件是 store 只读链接——本机没有 systemsettings，没有反写路径。
    xdg.configFile."kdeglobals" = {
      force = true;
      text = ''
        [General]
        ColorScheme=${theme.kde.scheme}

        [KDE]
        widgetStyle=breeze

        [Icons]
        Theme=breeze
      '';
    };
  };
}