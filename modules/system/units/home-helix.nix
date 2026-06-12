{ config, pkgs, user, ... }: {
  home-manager.users.${user} = {
    # ── Helix ─────────────────────────────────────────────────────
    programs.helix = {
      enable = true;
      settings = {
        theme = "gruvbox_dark_soft";
        editor = {
          line-number       = "relative";
          cursorline        = true;
          color-modes       = true;
          cursor-shape = {
            normal = "block";
            insert = "bar";
            select = "underline";
          };
          lsp.display-messages     = true;
          lsp.display-inlay-hints  = true;
          file-picker.hidden       = false;
          indent-guides.render     = true;
          soft-wrap.enable         = true;
          mouse                    = true;
          enable-steel             = true;
          trim-trailing-whitespace = true;
          trim-final-newlines      = true;
          popup-border             = "none";
          commandline              = false;
          auto-save.focus-lost     = true;
          auto-save.idle           = true;
        };
        keys.normal = {
          space.space = "goto_word";
          space.o = [
            ":sh rm -f /tmp/unique-file"
            ":insert-output yazi %{buffer_name} --chooser-file=/tmp/unique-file"
            ":insert-output echo \"\\x1b[?1049h\\x1b[?2004h\" > /dev/tty"
            ":open %sh{cat /tmp/unique-file}"
            ":redraw"
          ];
          "A-j" = "page_cursor_half_down";
          "A-k" = "page_cursor_half_up";
          "A-s" = "save_selection";
          "C-s" = "split_selection_on_newline";
          "A-h" = "jump_backward";
          "A-l" = "jump_forward";
        };
        keys.insert = {
          "A-;" = "normal_mode";
        };
        keys.select = {
          space.space = "goto_word";
          "A-;" = "normal_mode";
          "A-'" = "flip_selections";
          "A-j" = "page_cursor_half_down";
          "A-k" = "page_cursor_half_up";
        };
      };
      languages = {
        language-server.rust-analyzer = {
          command = "rust-analyzer";
          config.check.command = "clippy";
        };
        language-server.typescript-language-server = {
          command = "typescript-language-server";
          args    = [ "--stdio" ];
        };
        language = [
          {
            name      = "nushell";
            formatter = { command = "nufmt"; };
          }
          {
            name             = "rust";
            auto-format      = true;
            language-servers = [ "rust-analyzer" ];
          }
          {
            name             = "typescript";
            language-servers = [ "typescript-language-server" ];
          }
        ];
      };
    };
  };
}
