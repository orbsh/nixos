{ user, pkgs, ... }: {
  home-manager.users.${user} = {
    # 使用 fetchTree 引入本地大文件（保持纯评估，无需 git 提交）
    rime.wanxiang.src = (builtins.fetchTree {
      type = "file";
      url = "file:///nix/store/h1dwvavq0qxfr4rsfz4xvzqkdvcq3rif-wanxiang-lts-zh-hans.gram";
      narHash = "sha256-QIeVQWTBE3sIlHgFi3SKeXymdyBNoPbByDeuzRmcpHk=";
    }).outPath;
  };
}
