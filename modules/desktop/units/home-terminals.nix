{ pkgs, lib, ... }: {

  # ── 桌面终端工具 ──────────────────────────────────────────────
  home.packages = with pkgs; [
    zellij   # 终端复用（Ghostty 启动时自动 attach）
    neovide  # Neovim GUI（亚像素渲染 + 物理微动画）
  ];

  # ── Ghostty ───────────────────────────────────────────────────
  # home-manager 25.05 已有 programs.ghostty
  programs.ghostty = {
    enable = true;
    settings = {
      theme                 = "Arthur";
      font-family           = "Lilex";
      font-style            = "Regular";
      font-size             = 11;
      shell-integration     = "none";
      window-padding-x      = 2;
      window-padding-y      = 0;
      window-height         = 40;
      window-width          = 120;
      window-decoration     = false;
      command               = "${pkgs.zellij}/bin/zellij attach --create X";
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
        dimensions = { columns = 120; lines = 40; };
      };
      terminal.shell.program = "nu";
    };
  };
}
