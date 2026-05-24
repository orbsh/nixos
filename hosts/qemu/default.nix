{ inputs, pkgs, lib, ... }: {
  imports = [
    inputs.disko.nixosModules.disko

    ./hardware-configuration.nix  # 保留：内核模块、网络等硬件配置
    ./disk.nix

    ../../modules/common/sys.nix
    ../../modules/common/base.nix
    ../../modules/common/nix.nix
    ../../modules/common/users.nix
    ../../modules/common/network.nix
    ../../modules/common/extra.nix
    ../../modules/common/container.nix

    # 桌面环境 (COSMIC)
    ../../modules/gui/desktop.nix
    #../../modules/gui/laptop.nix

    # 开发工具
    # ../../modules/dev
  ];

  # QEMU/KVM guest: SPICE agent for clipboard sharing and auto-resolution
  services.spice-vdagentd.enable = true;

  # Use stable kernel for maximum guest compatibility
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  networking.hostName = "qemu";
}
