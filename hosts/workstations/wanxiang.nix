{ user, ... }: {
  home-manager.users.${user} = {
    # 启用八股文 N-Gram 语法模型
    rime.octagram.enable = true;

    # 万象模型（Nix 纯评估要求 fetchTree 必须提供 narHash）
    rime.wanxiang.src = (builtins.fetchTree {
      type = "file";
      url = "file:///nix/store/h1dwvavq0qxfr4rsfz4xvzqkdvcq3rif-wanxiang-lts-zh-hans.gram";
      narHash = "sha256-QIeVQWTBE3sIlHgFi3SKeXymdyBNoPbByDeuzRmcpHk=";
    }).outPath;
  };
}
