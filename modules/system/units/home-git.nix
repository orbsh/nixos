{ user, email, ... }: {
  home-manager.users.${user} = {
    programs.git = {
      enable      = true;

      signing = {
        # 用 SSH key 签名（比 GPG 简单）
        key    = "~/.ssh/id_ed25519.pub";
        signByDefault = true;
        format = "ssh";
        # 不钉 store path：HM 默认注入 pkgs.openssh 的绝对路径，
        # 与进程环境 LD_LIBRARY_PATH 的 glibc/gcc 版本错配时 ssh-keygen 直接
        # stack smashing（Nix 二进制 RUNPATH 排在 LD_LIBRARY_PATH 之后）。
        # PATH 解析让每个 shell 选中与自身环境兼容的那个 ssh-keygen。
        signer = "ssh-keygen";
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

    # delta —— 更好看的 diff（不自动作为 git pager）
    programs.delta = {
      enable = true;
      enableGitIntegration = false;
      options = {
        paging           = false;
        navigate         = true;
        side-by-side     = true;
        line-numbers     = true;
        syntax-theme     = "Catppuccin Mocha";
      };
    };
  };
}
