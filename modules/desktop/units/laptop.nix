{ pkgs, lib, ... }:

{
  # ── 电源管理（power-profiles-daemon） ────────────────────
  services.power-profiles-daemon.enable = true;

  # ── 合盖/睡眠行为（systemd-logind） ─────────────────────
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";            # 合盖挂起
    HandleLidSwitchExternalPower = "lock";  # 插电时合盖仅锁屏
    HandleLidSwitchDocked = "ignore";       # 在底座/扩展坞时忽略合盖
  };

  # ── 屏幕亮度控制 ────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    brightnessctl   # CLI 调节背光/亮度
    auto-cpufreq    # 自动 CPU 频率/功耗调节（可选启用）
  ];

  # ── 触控板手势 & 输入优化 ───────────────────────────────
  services.libinput = {
    enable = true;
    touchpad = {
      naturalScrolling = true;    # 自然滚动（双指反向）
      tapping = true;             # 轻触点击
      tappingDragLock = true;     # 拖拽锁定
      middleEmulation = true;     # 双指/三指模拟中键
      disableWhileTyping = true;  # 打字时禁用触控板
    };
  };

  # ── 蓝牙支持 ────────────────────────────────────────────
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;      # 启用 LE Audio 等新特性
        FastConnectable = true;
      };
    };
  };
  services.blueman.enable = true; # GTK 蓝牙管理器

  # ── 蓝牙 USB autosuspend 修复 ───────────────────────────
  # 休眠恢复后 xhci_hcd 无法重新枚举蓝牙适配器（0489:e111）
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", DRIVERS=="btusb", ATTR{power/autosuspend}="-1"
  '';

  # ── 温度/风扇管理（可选） ───────────────────────────────
  # services.thermald.enable = true;        # Intel CPU 温控
  # services.auto-cpufreq.enable = true;   # 替代 tlp 的轻量方案
}