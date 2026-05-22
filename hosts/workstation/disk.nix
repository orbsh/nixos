{ ... }: {
  disko.devices = {
    disk.internal = {
      device = "/dev/disk/by-id/nvme-eui.5cdfb805104023c3"
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              _create = false;
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            size = "100%";
            label = "disk-internal-root";
            content = {
              type = "filesystem";
              _create = false;
              format = "xfs";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
