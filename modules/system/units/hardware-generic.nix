{ pkgs, lib, ... }: {
  # ── 通用硬件支持 ──────────────────────────────────
  # 启用非自由固件与所有可能的固件，最大化对不同主板、WiFi、GPU 的兼容性
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;

  # 使用最新内核以获得更好的硬件驱动支持
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;

  # ── 文件系统支持 ──────────────────────────────────
  # 需能读写目标机器的各类分区
  boot.supportedFilesystems = [ "ntfs" "exfat" "ext4" "btrfs" "xfs" "vfat" ];

  # ── SSD 寿命优化 ──────────────────────────────────
  # 全局默认为所有文件系统禁用 atime 写入，减少不必要的磁盘写入
  fileSystems."/".options = lib.mkDefault [ "noatime" ];
  # 每周批量 TRIM，通知 SSD 清理已删除数据块，保持写入速度并延长寿命
  services.fstrim.enable = true;

  # ── 网络与存储管理 ────────────────────────────────
  # NetworkManager 提供通用的网络配置能力
  networking.networkmanager.enable = true;

  # ── 性能与体验 ───────────────────────────────────
  # 启用 zram 交换，提升低内存环境下的响应速度
  zramSwap.enable = true;

  # 快速启动，不等待用户选择
  boot.loader.timeout = lib.mkDefault 5;
}
