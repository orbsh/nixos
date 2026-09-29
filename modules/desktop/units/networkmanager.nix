{ pkgs, lib, ... }: {
  networking.wireless.enable = false;
  # ── NetworkManager（桌面网络管理）──────────────────────
  # 提供 GUI 网络配置、WiFi 管理、VPN 支持等桌面功能
  networking.networkmanager.enable = true;

  # WiFi 优化：使用 iwd 后端（比 wpa_supplicant 更稳定）
  networking.networkmanager.wifi.backend = "iwd";
  # 关闭 WiFi 省电模式，防止断流
  networking.networkmanager.wifi.powersave = false;
}
