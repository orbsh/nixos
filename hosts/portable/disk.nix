{ ... }: {
  disko.devices = {
    disk.main = {
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
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "fmask=0077" "dmask=0077" ];
              # 不创建/格式化 ESP，直接挂载现有的（如果已存在）
              _create = false;
            };
          };
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              # 关键：不创建/格式化现有的 Btrfs 分区，保留所有数据
              _create = false;

              # 定义现有的子卷结构
              # 注意：Key 必须是子卷名称（如 @, @home），而非挂载路径
              subvolumes = {
                "@" = {
                  mountpoint = "/";
                  mountOptions = [ "compress=zstd" ];
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [ "compress=zstd" ];
                };
                "@var" = {
                  mountpoint = "/var";
                  mountOptions = [ "compress=zstd" "noatime" ];
                };
                "@swap" = {
                  mountpoint = "/swap";
                  mountOptions = [ "noatime" ];
                };
              };
            };
          };
        };
      };
    };
  };

  # Swapfile 配置
  swapDevices = [{
    device = "/swap/swapfile";
    size = 16 * 1024; # 16GB
  }];
}
