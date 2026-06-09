{ config, pkgs, ... }: {

  # ── Helix ─────────────────────────────────────────────────────
  programs.helix = {
    enable = true;
    defaultEditor = true;
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
    # 额外的 LSP 和格式化工具
    extraPackages = with pkgs; [
      rust-analyzer
      typescript-language-server
      vscode-langservers-extracted  # html/css/json/eslint
      taplo                                       # TOML
      nil                                         # Nix LSP
      nufmt                                       # nushell 格式化
    ];
  };

  # ── Neovim ────────────────────────────────────────────────────
  # 用 home-manager 管配置文件，插件管理交给 lazy.nvim（运行时自装）
  programs.neovim = {
    enable       = true;
    vimAlias     = true;
    viAlias      = true;
    extraPackages = with pkgs; [
      # lazy.nvim 需要 git，已在 git.nix 里
      ripgrep   # telescope 依赖
      fd
    ];
  };

}
