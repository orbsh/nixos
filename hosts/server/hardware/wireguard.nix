{ pkgs, ... }: {
  # WireGuard 接口（实例数量按需增减；密钥文件不进 nix 配置，
  # 由 /etc/wireguard/<name>.conf 手工管理）
  networking.wg-quick.interfaces = {
    wg0 = {
      configFile = "/etc/wireguard/wg0.conf";
      autostart = true;
    };
    wg3 = {
      configFile = "/etc/wireguard/wg3.conf";
      autostart = true;
    };
  };

  # dhcpcd 默认管理所有接口，会把 wg0 当普通网卡删除/重新配置
  # （journal 实证 "wg0: removing interface"），导致隧道瞬断。
  # glob 排除所有 wg 实例与 tailscale*（tailscaled 自管）。
  networking.dhcpcd.denyInterfaces = [ "wg*" "tailscale*" ];

  # WireGuard 工具
  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];
}
