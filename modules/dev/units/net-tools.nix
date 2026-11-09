{ pkgs, lib, config, ... }:
let
  # mitmproxy 12.3.0 的 test_emudhra 用 SHA-1 签署的测试根证书链（eMudhra / Comodo AAA），
  # OpenSSL 3.5 起在握手时直接 reject，断言必失败（上游 12.3.1 已 bump，但 nixos-unstable 还没到，
  # 本 rev 的 cache 里也没有替代产物）。禁用这两个用例，其余 1800+ 个照跑。
  mitmproxy = pkgs.mitmproxy.overridePythonAttrs (old: {
    disabledTests = (old.disabledTests or [ ]) ++ [ "test_emudhra" ];
  });
in {
  # 网络抓包与分析工具 (Wireshark 生态)
  environment.systemPackages = [
    pkgs.termshark   # TUI 版 Wireshark
    mitmproxy        # HTTP/HTTPS 中间人代理，用于调试 API 流量
    pkgs.nmap        # 端口扫描与网络探测工具
  ];

  # Wireshark GUI + dumpcap capability
  # 自动将所有 normal users 加入 wireshark 组以允许抓包
  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };
  users.groups.wireshark.members = lib.attrNames (
    lib.filterAttrs (name: user: user.isNormalUser or false) config.users.users
  );
}
