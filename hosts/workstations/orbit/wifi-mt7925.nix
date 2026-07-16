{ pkgs, ... }: {
  # mt7925e 驱动 suspend/resume 后状态退化，自动重连 WiFi 清除
  systemd.services.wifi-reconnect = {
    description = "Reconnect WiFi after resume (mt7925e workaround)";
    wantedBy = [ "sleep.target" ];
    after = [ "sleep.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      sleep 3
      ${pkgs.networkmanager}/bin/nmcli radio wifi off
      sleep 2
      ${pkgs.networkmanager}/bin/nmcli radio wifi on
    '';
  };
}
