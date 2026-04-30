{ pkgs, lib, ... }: {

  # ── Ghostty ───────────────────────────────────────────────────
  # home-manager 25.05 已有 programs.ghostty
  programs.ghostty = {
    enable = true;
    settings = {
      theme                 = "Arthur";
      font-family           = "Lilex";
      font-style            = "Regular";
      font-size             = 11;
      shell-integration     = "detect";
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
        dimensions = { columns = 120; lines = 40; };
      };
      terminal.shell.program = "nu";
    };
  };

  # ── Zellij ────────────────────────────────────────────────────
  programs.zellij = {
    enable = true;

    settings = {
      theme             = "gruvbox-dark";
      default_shell     = "nu";
      pane_frames       = false;
      simplified_ui     = true;
      default_layout    = "compact";
      scrollback_editor = "hx";
      keybinds = {
        unbind = [ "Ctrl g" "Ctrl p" "Ctrl n" "Ctrl t" "Ctrl s" "Ctrl q" ];
        normal = {
          bind = {
            "Ctrl Alt i"     = [ "SwitchToMode Tab" ];
            "Ctrl Alt o"     = [ "EditScrollback" ];
            "Ctrl Alt p"     = [ "SwitchToMode Pane" ];
            "Ctrl Alt m"     = [ "SwitchToMode Move" ];
            "Ctrl Alt s"     = [ "SwitchToMode EnterSearch" ];
            "Ctrl Alt w"     = [ "SwitchToMode renametab" "TabNameInput 0" ];
            "Ctrl Alt n"     = [ "NewPane" ];
            "Ctrl Alt /"     = [ "NextSwapLayout" ];
            "Ctrl Alt Space" = [ "ToggleFloatingPanes" ];
            "Ctrl Alt x"     = [ "CloseFocus" ];
            "Ctrl Alt ,"     = [ "PageScrollUp" ];
            "Ctrl Alt ."     = [ "PageScrollDown" ];
            "Ctrl Alt h"     = [ "MoveFocusOrTab Left" ];
            "Ctrl Alt l"     = [ "MoveFocusOrTab Right" ];
            "Ctrl Alt j"     = [ "MoveFocus Down" ];
            "Ctrl Alt k"     = [ "MoveFocus Up" ];
            "Alt Shift h"    = [ "MoveTab left" ];
            "Alt Shift l"    = [ "MoveTab right" ];
            "Ctrl Alt q"     = [ "Quit" ];
            "Ctrl Alt d"     = [ "Detach" ];
          };
        };
      };
    };
  };
}
