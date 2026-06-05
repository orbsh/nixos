{ ... }: {
  disko.devices = {
    disk.main = {
      device = "/dev/vda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          bios_boot = {
            size = "1M";
            type = "EF02";
          };
          root = {
            size = "100%";
            content = { type = "filesystem"; format = "xfs"; mountpoint = "/"; mountOptions = [ "noatime" ]; };
          };
        };
      };
    };
  };
}
