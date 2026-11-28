# KDE/Qt 主题单元：Dolphin 等 Qt/KDE 应用统一走 gruvbox light 配色 + Kvantum 控件风格。
# 背景：niri 会话没有 Plasma，Dolphin 原先吃 Qt 默认 Fusion 调色板（蓝色选中/hover）；
# ~/.config/kdeglobals 里只有 ColorSchemeHash、没有 ColorScheme，等于没有任何配色声明。
# 链路（三段各管一件事，缺一段就会出现蓝色/灰色残留）：
#   plasma-integration  → kde 平台主题：Qt 应用从 kdeglobals 取调色板、字体、图标主题
#   kvantum             → 控件风格（QStyle 插件）：按钮/输入框/滚动条的绘制
#   GruvboxLight.colors → KDE 语义色：视图底色、交替行、选中、焦点描边（Dolphin 文件区靠它）
{ pkgs, lib, user, ... }:
let
  # ── gruvbox light 官方色板（KDE ColorScheme 要求 "r,g,b" 三元组）──
  palette = {
    bg            = "251,241,199"; # #fbf1c7 bg0   视图/窗口底
    bgAlt         = "242,229,188"; # #f2e5bc bg0_s 交替行
    bgTooltip     = "249,245,215"; # #f9f5d7 bg0_h 提示框底
    bgButton      = "235,219,178"; # #ebdbb2 bg1   按钮底
    bgButtonAlt   = "213,196,161"; # #d5c4a1 bg2   按钮悬停
    bgSelection   = "213,196,161"; # #d5c4a1 bg2   选中底
    bgSelectionAlt = "189,174,147"; # #bdae93 bg3  隔行选中
    fg            = "60,56,54";    # #3c3836 fg1   正文
    fgSelection   = "40,40,40";    # #282828 fg0   选中正文
    fgInactive    = "124,111,100"; # #7c6f64 fg4   次要/失焦
    fgInactiveSel = "102,92,84";   # #665c54 fg3   选中里的次要文字
    focus         = "181,118,20";  # #b57614 yellow 焦点描边（即"浅黄"）
    hover         = "215,153,33";  # #d79921 yellow 悬停描边
    orange        = "175,58,3";    # #af3a03 激活
    blue          = "7,102,120";   # #076678 链接
    purple        = "143,63,113";  # #8f3f71 已访问
    red           = "157,0,6";     # #9d0006 否定/错误
    green         = "121,116,14";  # #79740e 肯定
  };

  # 每个 Colors:* 段共用的 12 个键（KDE 语义色标准集合，缺键会回落到 Breeze 默认色）
  colorSet = bg: bgAlt: fg: fgInactive: lib.concatStrings [
    "BackgroundAlternate=${bgAlt}\n"
    "BackgroundNormal=${bg}\n"
    "DecorationFocus=${palette.focus}\n"
    "DecorationHover=${palette.hover}\n"
    "ForegroundActive=${palette.orange}\n"
    "ForegroundInactive=${fgInactive}\n"
    "ForegroundLink=${palette.blue}\n"
    "ForegroundNegative=${palette.red}\n"
    "ForegroundNeutral=${palette.focus}\n"
    "ForegroundNormal=${fg}\n"
    "ForegroundPositive=${palette.green}\n"
    "ForegroundVisited=${palette.purple}\n"
  ];

  section = name: body: "[Colors:${name}]\n${body}\n";

  colorScheme = lib.concatStrings [
    "[General]\n"
    "ColorScheme=GruvboxLight\n"
    "Name=Gruvbox Light\n"
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
  # ── 系统级：Qt 平台主题 + Kvantum 插件 + gruvbox 皮肤 ──
  environment.systemPackages = [
    pkgs.kdePackages.plasma-integration
    pkgs.kdePackages.qtstyleplugin-kvantum
    (pkgs.gruvbox-kvantum.override { variant = "Gruvbox_Light_Brown"; })
  ];

  # 不用 qt.enable：它会连带装 kdePackages.systemsettings + kio（整套 Plasma 设置面板，
  # 在 niri 里没用），而插件路径这里只需两条。
  # 用 environment.variables（fcitx5 模块也在这里放 QT_PLUGIN_PATH）：列表形式由该选项的
  # apply 按 ":" 拼接；改用 sessionVariables 会因为「列表 vs 已拼接字符串」两个定义撞类型。
  environment.variables = {
    QT_QPA_PLATFORMTHEME = "kde";
    QT_STYLE_OVERRIDE = "kvantum";
    # systemPackages 里的 Qt 插件不会自动进 QT_PLUGIN_PATH；与 fcitx5 的条目合并成一条
    QT_PLUGIN_PATH = [
      "${pkgs.kdePackages.plasma-integration}/${qtPluginPrefix}"
      "${pkgs.kdePackages.qtstyleplugin-kvantum}/${qtPluginPrefix}"
    ];
  };

  # ── 用户级：配色方案 + kdeglobals + Kvantum 皮肤选择 ──
  home-manager.users.${user} = {
    xdg.dataFile."color-schemes/GruvboxLight.colors".text = colorScheme;

    # force：现存 ~/.config/kdeglobals 是 KDE 应用自写的普通文件，HM 需要接管。
    # 接管后该文件是 store 只读链接——本机没有 systemsettings，没有反写路径。
    xdg.configFile."kdeglobals" = {
      force = true;
      text = ''
        [General]
        ColorScheme=GruvboxLight

        [KDE]
        widgetStyle=kvantum

        [Icons]
        Theme=breeze
      '';
    };

    # Kvantum 只读自己的 kvconfig，不认 kdeglobals；皮肤目录由 gruvbox-kvantum 装进 profile 的 share/Kvantum
    xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=Gruvbox_Light_Brown
    '';
  };
}