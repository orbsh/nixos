# 桌面主题数据表：一个主题 = 各消费方需要的那一小段数据，集中在这一处改。
# 谁消费什么：
#   units/theme.nix       读 config.desktop.theme，选出主题记录注入 _module.args.theme
#   units/kde-qt-theme.nix      theme.kde            → ~/.local/share/color-schemes/*.colors + kdeglobals
#   units/home-terminals.nix    theme.ghostty        → Ghostty theme 名（Ghostty 内置主题）
#                               theme.alacritty.dark → Alacritty 没有主题机制，直接给色表（用同主题深色版）
#   units/herdr.nix             theme.herdr          → 基底主题 + token 覆盖
#   de-session/niri.nix         theme.niri           → 生成 ~/.config/niri/theme.kdl（config.kdl 里 include）
{
  flexoki-light = {
    label = "Flexoki Light";

    # KDE 语义色（kepano/flexoki 官方值；hex 会被生成器转成 "r,g,b"）
    kde = {
      scheme = "FlexokiLight";
      palette = {
        bg             = "#FFFCF0"; # paper
        bgAlt          = "#F2F0E5"; # base-50
        bgTooltip      = "#FFFCF0"; # paper
        bgButton       = "#F2F0E5"; # base-50
        bgButtonAlt    = "#E6E4D9"; # base-100
        bgSelection    = "#E6E4D9"; # base-100
        bgSelectionAlt = "#DAD8CE"; # base-150
        fg             = "#100F0F"; # black
        fgSelection    = "#100F0F"; # black
        fgInactive     = "#6F6E69"; # base-600
        fgInactiveSel  = "#575653"; # base-700
        focus          = "#BC5215"; # orange-600
        hover          = "#DA702C"; # orange-400
        blue           = "#205EA6"; # blue-600
        purple         = "#5E409D"; # purple-600
        red            = "#AF3029"; # red-600
        yellow         = "#AD8301"; # yellow-600
        green          = "#66800B"; # green-600
      };
    };

    niri = {
      focus    = "#BC5215"; # 与 KDE 焦点描边同色
      inactive = "#75524A"; # 别的显示器上仍带焦点的窗口（单屏不显示）
      urgent   = "#C0392B";
    };

    ghostty = "Flexoki Light"; # Ghostty 内置主题

    # Alacritty 色表（同主题的两个明暗版；Ghostty 内置值）
    alacritty = {
      light = {
        primary = {
          background = "#fffcf0";
          foreground = "#100f0f";
        };
        normal = {
          black   = "#100f0f";
          red     = "#af3029";
          green   = "#66800b";
          yellow  = "#ad8301";
          blue    = "#205ea6";
          magenta = "#a02f6f";
          cyan    = "#24837b";
          white   = "#6f6e69";
        };
        bright = {
          black   = "#b7b5ac";
          red     = "#d14d41";
          green   = "#879a39";
          yellow  = "#d0a215";
          blue    = "#4385be";
          magenta = "#ce5d97";
          cyan    = "#3aa99f";
          white   = "#cecdc3";
        };
        cursor = {
          text   = "#fffcf0";
          cursor = "#100f0f";
        };
        selection = {
          background = "#cecdc3";
          text       = "#100f0f";
        };
      };

      dark = {
        primary = {
          background = "#100f0f";
          foreground = "#cecdc3";
        };
        normal = {
          black   = "#100f0f";
          red     = "#d14d41";
          green   = "#879a39";
          yellow  = "#d0a215";
          blue    = "#4385be";
          magenta = "#ce5d97";
          cyan    = "#3aa99f";
          white   = "#878580";
        };
        bright = {
          black   = "#575653";
          red     = "#af3029";
          green   = "#66800b";
          yellow  = "#ad8301";
          blue    = "#205ea6";
          magenta = "#a02f6f";
          cyan    = "#24837b";
          white   = "#cecdc3";
        };
        cursor = {
          text   = "#100f0f";
          cursor = "#cecdc3";
        };
        selection = {
          background = "#403e3c";
          text       = "#cecdc3";
        };
      };
    };

    # herdr 没有内置 flexoki：用 gruvbox-light 作暖底基底，再覆盖它画的 UI token
    herdr = {
      base = "gruvbox-light";
      custom = {
        accent        = "#bc5215";
        sidebar_bg    = "#f2f0e5";
        active_row_bg = "#e6e4d9";
        selection_bg  = "#dad8ce";
        surface_dim   = "#e6e4d9";
        mauve         = "#5e409d";
        green         = "#66800b";
        yellow        = "#ad8301";
        red           = "#af3029";
        peach         = "#da702c";
      };
    };
  };

  gruvbox-light = {
    label = "Gruvbox Light";

    kde = {
      scheme = "GruvboxLight";
      palette = {
        bg             = "#FBF1C7"; # bg0
        bgAlt          = "#F2E5BC"; # bg0_s
        bgTooltip      = "#F9F5D7"; # bg0_h
        bgButton       = "#EBDBB2"; # bg1
        bgButtonAlt    = "#D5C4A1"; # bg2
        bgSelection    = "#D5C4A1"; # bg2
        bgSelectionAlt = "#BDAE93"; # bg3
        fg             = "#3C3836"; # fg1
        fgSelection    = "#282828"; # fg0
        fgInactive     = "#7C6F64"; # fg4
        fgInactiveSel  = "#665C54"; # fg3
        focus          = "#B57614"; # yellow
        hover          = "#D79921"; # yellow
        blue           = "#076678";
        purple         = "#8F3F71";
        red            = "#9D0006";
        yellow         = "#B57614";
        green          = "#79740E";
      };
    };

    niri = {
      focus    = "#98971A"; # 之前手动挑的橄榄绿环
      inactive = "#75524A";
      urgent   = "#C0392B";
    };

    ghostty = "Gruvbox Light"; # Ghostty 内置主题

    alacritty = {
      light = {
        primary = {
          background = "#fbf1c7";
          foreground = "#3c3836";
        };
        normal = {
          black   = "#fbf1c7";
          red     = "#cc241d";
          green   = "#98971a";
          yellow  = "#d79921";
          blue    = "#458588";
          magenta = "#b16286";
          cyan    = "#689d6a";
          white   = "#7c6f64";
        };
        bright = {
          black   = "#928374";
          red     = "#9d0006";
          green   = "#79740e";
          yellow  = "#b57614";
          blue    = "#076678";
          magenta = "#8f3f71";
          cyan    = "#427b58";
          white   = "#3c3836";
        };
        cursor = {
          text   = "#fbf1c7";
          cursor = "#3c3836";
        };
        selection = {
          background = "#3c3836";
          text       = "#fbf1c7";
        };
      };

      dark = {
        primary = {
          background = "#282828";
          foreground = "#ebdbb2";
        };
        normal = {
          black   = "#282828";
          red     = "#cc241d";
          green   = "#98971a";
          yellow  = "#d79921";
          blue    = "#458588";
          magenta = "#b16286";
          cyan    = "#689d6a";
          white   = "#a89984";
        };
        bright = {
          black   = "#928374";
          red     = "#fb4934";
          green   = "#b8bb26";
          yellow  = "#fabd2f";
          blue    = "#83a598";
          magenta = "#d3869b";
          cyan    = "#8ec07c";
          white   = "#ebdbb2";
        };
        cursor = {
          text   = "#282828";
          cursor = "#ebdbb2";
        };
        selection = {
          background = "#665c54";
          text       = "#ebdbb2";
        };
      };
    };

    # gruvbox-light 是 herdr 内置主题，不需要覆盖 token
    herdr = {
      base = "gruvbox-light";
      custom = { };
    };
  };
}