{ ... }: {
  disko.devices = {
    disk.internal = {
      device = "/dev/disk/by-id/usb-EAGET_USB_3.2_202302090772-0:0";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              # _create = false;
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            size = "100%";
            label = "disk-portable-root";
            content = {
              type = "filesystem";
              # _create = false;
              format = "xfs";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
