{ pkgs, lib, user, ... }: {
  imports = [
    # 核心系统预设 + Home Manager 配置
    ../system/core.nix
    ../system/home.nix

    # ../services/virt.nix

    ../desktop/base.nix
    ../desktop/home.nix
    ../services/ladder.nix
  ];


  # udisks2 用于自动挂载可移动设备
  services.udisks2.enable = true;

  # 自动登录
  services.getty.autologinUser = user;
}
