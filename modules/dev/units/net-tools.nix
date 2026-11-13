{ pkgs, lib, config, ... }: {
  # 网络抓包与分析工具 (Wireshark 生态)
  environment.systemPackages = [
    pkgs.termshark   # TUI 版 Wireshark
    pkgs.mitmproxy   # HTTP/HTTPS 中间人代理，用于调试 API 流量
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
