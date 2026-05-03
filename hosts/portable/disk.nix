{ ... }: {
  disko.devices = {
    disk.main = {
      # 注意：默认指向第一块 SATA 磁盘。若安装到 NVMe 需改为 "/dev/nvme0n1"
      device = "/dev/sda";
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
            label = "disk-main-root";
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
