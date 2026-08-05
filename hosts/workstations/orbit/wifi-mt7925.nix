{ pkgs, lib, ... }:
# ── MT7925(Wi-Fi 6E) 网卡修复 ─────────────────────────────
# 根因：mt7925e 驱动的 PCIe ASPM(省电) 在 suspend/resume 后引发接收链路退化，
#       表现为休眠后吞吐骤降、网关时延飙到 100ms+、Rx 速率被卡在最低 MCS。
#       实测关闭 ASPM 后 Rx 从 58.6Mbit/s 恢复 866.7Mbit/s，网关时延 134ms→0.9ms。
# 方案：模块加载时强制 disable_aspm=1（对模块生命周期生效，resume 后仍保持关闭）。
{
  # 模块加载即关闭 ASPM（比 resume 服务更彻底，Boot 后整个生命周期都生效）
  boot.extraModprobeConfig = ''
    options mt7925e disable_aspm=1
  '';

  # 冗余保险：resume 后重载驱动，确保任何情况下链路都重建
  # （disable_aspm 是加载期参数，重载时会自动套用上面 extraModprobeConfig 的选项）
  systemd.services.wifi-reconnect = {
    description = "Reload mt7925e driver after resume (ASPM workaround)";
    # 挂到 resume 目标（suspend/hibernate/hybrid），而非 sleep.target（那是进入睡眠前）
    wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target" ];
    after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target" "NetworkManager.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      sleep 2
      ${pkgs.networkmanager}/bin/nmcli radio wifi off
      sleep 2
      rmmod mt7925e 2>/dev/null || true
      sleep 1
      modprobe mt7925e
      sleep 3
      ${pkgs.networkmanager}/bin/nmcli radio wifi on
      ${pkgs.networkmanager}/bin/nmcli device reapply wlan0 2>/dev/null || true
    '';
  };
}
