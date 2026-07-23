{ pkgs, lib, user, ... }: {
  imports = [
    ../system/core.nix
    ../system/home.nix

    # ../services/virt.nix

    ../desktop/base.nix
    ../desktop/home.nix
    ../services/ladder.nix

    ../dev/rescue.nix
  ];

  # 移动硬盘不能修改 EFI 变量，否则在宿主机安装时会写到宿主机的 EFI
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # udisks2 用于自动挂载可移动设备
  services.udisks2.enable = true;

  # 自动登录
  services.getty.autologinUser = user;
}
