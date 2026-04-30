{ ... }: {
  programs.git = {
    enable      = true;
    settings.user.name  = "master";
    settings.user.email = "you@example.com";   # 改成你的邮箱

    signing = {
      # 用 SSH key 签名（比 GPG 简单）
      key    = "~/.ssh/id_ed25519.pub";
      signByDefault = true;
      format = "ssh";
    };

    settings = {
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
      navigate         = true;
      side-by-side     = true;
      line-numbers     = true;
      syntax-theme     = "Catppuccin Mocha";
    };
  };

}
