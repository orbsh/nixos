{ pkgs, lib, user, ... }: {
  imports = [
    ../system/core.nix

    ../dev/rescue.nix

    ../desktop/base.nix

    # ../services/virt.nix
    ../services/ladder.nix
  ];

  # 移动硬盘不能修改 EFI 变量，否则在宿主机安装时会写到宿主机的 EFI
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # udisks2 用于自动挂载可移动设备
  services.udisks2.enable = true;

  # 自动登录
  services.getty.autologinUser = user;
}
