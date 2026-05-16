{ ... }: {
  # ── 文件系统挂载（基于 UUID，不格式化）──────────────
  # 注意：以下 UUID 为占位符，需根据实际磁盘调整（使用 `lsblk -f` 查看）
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/3cebac0d-9bea-4640-8826-96ccead1fdf7";
    fsType = "xfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/CCDD-602A";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  # ── 交换设备 ──────────────────────────────────────
  swapDevices = [ ];
}
