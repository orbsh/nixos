{ ... }: {
  disko.devices = {
    disk.main = {
      device = "/dev/sda";   # QEMU default disk (SATA or virtio)
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
              mountOptions = [ "noatime" ];
            };
          };
          root = {
            size = "100%";
            label = "disk-main-root";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/";
              mountOptions = [ "noatime" ];
            };
          };
        };
      };
    };
  };
}