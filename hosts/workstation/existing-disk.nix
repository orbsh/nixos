{ ... }: {
  # ── 文件系统挂载（基于 UUID，不格式化）──────────────
  # 注意：UUID 需根据实际磁盘调整（使用 `lsblk -f` 查看）
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/dfd51d2d-db10-4a63-82d7-10c4f59418e0";
    fsType = "xfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/8C1A-FBE8";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  # ── 交换设备 ──────────────────────────────────────
  swapDevices = [ ];
}
