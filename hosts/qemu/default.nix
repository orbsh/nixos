{ inputs, pkgs, lib, ... }: {
  imports = [
    inputs.disko.nixosModules.disko

    ./hardware-configuration.nix  # 保留：内核模块、网络等硬件配置
    ./disk.nix

    ../../modules/system/sys.nix
    ../../modules/system/base.nix
    ../../modules/system/nix.nix
    ../../modules/system/users.nix
    ../../modules/system/network.nix
    ../../modules/system/extra.nix
    ../../modules/system/container.nix

    # 桌面环境 (COSMIC)
    ../../modules/desktop/desktop.nix
    #../../modules/desktop/laptop.nix

    # 开发工具
    # ../../modules/dev
  ];

  # QEMU/KVM guest: SPICE agent for clipboard sharing and auto-resolution
  services.spice-vdagentd.enable = true;

  # Use stable kernel for maximum guest compatibility
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  networking.hostName = "qemu";
}
