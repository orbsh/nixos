{ ... }: {
  # nixpkgs 源码构建在 binutils 2.46 下链接失败且无 prebuilt（每次全量编译），走官方 release 二进制
  herdr.prebuilt = {
    version = "0.9.3";
    src = {
      url = "http://box.d/nixos/herdr-0.9.3-linux-x86_64";
      narHash = "sha256-/WcKIYpizQz7BmbKaN7jQVnCoT5I+PPuVJzZmVuPPdw=";
    };
  };
}
