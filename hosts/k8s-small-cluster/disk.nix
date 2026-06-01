{ ... }: {
  disko.devices = {
    disk.main = {
      device = "/dev/vda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "2G";
            content = { type = "filesystem"; format = "ext4"; mountpoint = "/boot"; };
          };
          root = {
            size = "100%";
            content = { type = "filesystem"; format = "xfs"; mountpoint = "/"; };
          };
        };
      };
    };
  };
}
