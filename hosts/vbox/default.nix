{ inputs, pkgs, lib, ... }: {
  imports = [
    inputs.disko.nixosModules.disko

    ./hardware-configuration.nix  # 保留：内核模块、网络等硬件配置
    ./disk.nix

    ../../modules/common/sys.nix
    ../../modules/common/base.nix
    ../../modules/common/users.nix
    ../../modules/common/network.nix
    ../../modules/common/extra.nix
    ../../modules/common/container.nix

    # 桌面环境 (COSMIC)
    ../../modules/workstation/desktop.nix
    #../../modules/workstation/laptop.nix

    # 开发工具
    # ../../modules/dev
  ];

  # VirtualBox 客户机增强功能 (共享剪贴板、自动分辨率等)
  virtualisation.virtualbox.guest.enable = true;

  # 使用稳定内核，避免 linuxPackages_latest 与 VBox GuestAdditions 不兼容
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  networking.hostName = "vbox";
}
