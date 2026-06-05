# Alice 的硬件配置
{ config, lib, pkgs, modulesPath, ... }: {
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" ];
  fileSystems."/" = { device = "/dev/nvme0n1p2"; fsType = "ext4"; options = [ "noatime" ]; };
  fileSystems."/boot" = { device = "/dev/nvme0n1p1"; fsType = "vfat"; options = [ "noatime" ]; };
}
