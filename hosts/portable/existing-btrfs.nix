{ ... }: {
  # ── 文件系统挂载（基于 UUID，不格式化）──────────────
  # 注意：UUID 需根据实际磁盘调整（使用 `lsblk -f` 查看）
  fileSystems."/efi" = {
    device = "/dev/disk/by-uuid/0CCB-BDC0";
    fsType = "vfat";
    # 如果是引导分区，建议加上以下参数
    options = [ "fmask=0077" "dmask=0077" ];
  };
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/3f9631a2-51ab-448a-9ac2-3b475fde7458";
    fsType = "btrfs";
    options = [ "subvol=@" "compress=zstd" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/3f9631a2-51ab-448a-9ac2-3b475fde7458";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" ];
  };

  fileSystems."/var" = {
    device = "/dev/disk/by-uuid/3f9631a2-51ab-448a-9ac2-3b475fde7458";
    fsType = "btrfs";
    options = [ "subvol=@var" "compress=zstd" "noatime" ];
  };

  fileSystems."/swap" = {
    device = "/dev/disk/by-uuid/3f9631a2-51ab-448a-9ac2-3b475fde7458";
    fsType = "btrfs";
    options = [ "subvol=@swap" ];
  };

  swapDevices = [{
    device = "/@swap/swapfile";
    size = 16 * 1024;
  }];
}
