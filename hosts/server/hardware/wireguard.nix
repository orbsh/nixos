{ pkgs, ... }: {
  # WireGuard 接口（密钥文件用 sops-nix 或 agenix 管理）
  networking.wg-quick.interfaces = {
    wg0 = {
      configFile = "/etc/wireguard/wg0.conf";
      autostart = true;
    };
  };

  # WireGuard 工具
  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];
}
