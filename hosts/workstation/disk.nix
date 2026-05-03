{ ... }: {
  disko.devices = {
    disk.internal = {
      device = "/dev/nvme0n1"; # 内置 NVMe 硬盘（请根据 lsblk 确认）
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            size = "100%";
            label = "disk-internal-root";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}