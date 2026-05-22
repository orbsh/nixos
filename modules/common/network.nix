{ pkgs, ... }: {
  networking = {
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 2222 6443 ];
    };

    # ── WiFi 优化配置 ────────────────────────────────
    # 使用 iwd 后端并关闭省电模式，防止断流
    # (适用于所有启用 NetworkManager 的主机，无 WiFi 的设备会自动忽略)
    networkmanager.wifi.backend = "iwd";
    networkmanager.wifi.powersave = false;
  };

  # 网络诊断与管理工具
  environment.systemPackages = with pkgs; [
    netcat
    openresolv
  ];
}
