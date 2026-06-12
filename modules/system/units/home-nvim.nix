{ config, pkgs, user, ... }: {
  home-manager.users.${user} = {
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
  };
}
