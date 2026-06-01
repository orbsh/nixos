{ pkgs, lib, user, ... }: {
  imports = [
    # 核心系统预设
    ../system/core.nix
    ../system/units/hardware-generic.nix
    # ../system/units/vm.nix

    ../desktop/base.nix
    ../podman/ladder.nix
  ];

  # 用户环境配置 (Desktop)
  home-manager.users.${user} = {
    imports = [ ../home/desktop.nix ];
  };

  # udisks2 用于自动挂载可移动设备
  services.udisks2.enable = true;

  # 自动登录
  services.getty.autologinUser = user;
}
