{ ... }: {
  rime.octagram.enable = true;

  rime.wanxiang.src = (builtins.fetchTree {
    type = "file";
    url = "file:///nix/store/h1dwvavq0qxfr4rsfz4xvzqkdvcq3rif-wanxiang-lts-zh-hans.gram";
    narHash = "sha256-QIeVQWTBE3sIlHgFi3SKeXymdyBNoPbByDeuzRmcpHk=";
  }).outPath;
}
