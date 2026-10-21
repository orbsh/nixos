{ ... }: {
  # nixpkgs 源码构建在 binutils 2.46 下链接失败且无 prebuilt（每次全量编译），走官方 release 二进制
  herdr.prebuilt = {
    version = "0.9.5";
    src = {
      url = "http://box.d/nixos/herdr-0.9.5-linux-x86_64";
      narHash = "sha256-Oii5/dTdw54oSRTnFhezO+XQU8vek8K+jrLUpMiTWRA=";
    };
  };
}
