{ user, email, ... }: {
  programs.git = {
    enable      = true;

    signing = {
      # 用 SSH key 签名（比 GPG 简单）
      key    = "~/.ssh/id_ed25519.pub";
      signByDefault = true;
      format = "ssh";
    };

    settings = {
      user = {
        name  = user;
        email = email;
      };
      init.defaultBranch   = "main";
      push.autoSetupRemote = true;
      pull.rebase          = true;
      rebase.autoStash     = true;
      merge.conflictstyle  = "zdiff3";
      diff.algorithm       = "histogram";
      core = {
        editor    = "hx";
        autocrlf  = false;
      };
      url = {
        # 内网 gitea
        "git@iffy.me:".insteadOf = "https://iffy.me/";
      };
    };

    ignores = [
      ".DS_Store"
      "*.swp"
      ".direnv"
      ".env"
      "result"
      "result-*"
    ];
  };

  # delta —— 更好看的 diff
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      paging           = false;
      navigate         = true;
      side-by-side     = true;
      line-numbers     = true;
      syntax-theme     = "Catppuccin Mocha";
    };
  };

}
