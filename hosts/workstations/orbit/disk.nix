{ ... }: {
  # ── 文件系统挂载（基于 UUID，不格式化）──────────────
  # 注意：UUID 需根据实际磁盘调整（使用 `lsblk -f` 查看）
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/77970593-3c29-4fa9-9b4e-411376274d06";
    fsType = "xfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/B0A9-1CC6";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  # ── 交换设备 ──────────────────────────────────────
  swapDevices = [ ];
}
