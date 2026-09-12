{ pkgs, lib, ... }: {

  # ── 桌面终端工具 ──────────────────────────────────────────────
  home.packages = with pkgs; [
    neovide  # Neovim GUI（亚像素渲染 + 物理微动画）
  ];

  # ── Neovide ────────────────────────────────────────────────────
  programs.neovide = {
    enable = true;
    settings = {
      box-drawing = {
        mode = "native";
      };
    };
  };

  # ── Ghostty ───────────────────────────────────────────────────
  # home-manager 25.05 已有 programs.ghostty
  programs.ghostty = {
    enable = true;
    settings = {
      theme                 = "Gruvbox Light";
      font-family           = "Lilex";
      font-style            = "Regular";
      font-size             = 13;
      # background-opacity    = 0.8;
      shell-integration     = "none";
      # nvim 在 herdr pane 里用 OSC 52 写系统剪贴板（默认 ask 会拦）
      clipboard-write        = "allow";
      # 整窗关闭不弹确认（Ghostty 默认开；herdr 场景直接退出无影响）
      confirm-close-surface = false;
      window-padding-x      = 2;
      window-padding-y      = 0;
      window-height         = 40;
      window-width          = 120;
      window-decoration     = false;
      keybind = [
        "clear"
        "ctrl+shift+comma=reload_config"
        "ctrl+shift+v=paste_from_clipboard"
        "ctrl+shift+p=paste_from_selection"
        "ctrl+shift+m=toggle_maximize"
      ];
    };
  };

  # ── Alacritty ─────────────────────────────────────────────────
  # 备用终端
  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "alacritty";
      font = {
        size = 10.5;
        normal.family = "Lilex";
        offset = { x = 0; y = 0; };
      };
      window = {
        decorations = "none";
        # opacity = 0.8;
        dimensions = { columns = 120; lines = 40; };
      };
      terminal.shell.program = "nu";
    };
  };
}
