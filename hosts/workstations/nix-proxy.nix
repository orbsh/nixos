# nix-daemon 代理：cache.nixos.org 走本地代理，镜像走直连
{ ... }: {
  nix.proxy = {
    address = "http://127.0.0.1:7890";
    noProxy = [
      "mirrors.ustc.edu.cn"
      "mirrors.tuna.tsinghua.edu.cn"
      "mirrors.sjtug.sjtu.edu.cn"
      "localhost"
      "127.0.0.1"
      "::1"
    ];
  };

  # Vicinae 插件/专区 store 下载：同用本机 Clash 代理（server 进程拉取，经 vicinae.service 环境注入）
  programs.vicinae.proxy = "http://127.0.0.1:7890";
}
