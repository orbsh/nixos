# 服务器角色基座
{ pkgs, user, ... }: {
  imports = [
    ../system/core.nix
    ../system/units/hardware-generic.nix  # 通用硬件配置
    ../system/units/vm.nix
    ../dev/server.nix
  ];

  home-manager.users.${user} = {
    imports = [ ../home/headless.nix ];
  };
}
