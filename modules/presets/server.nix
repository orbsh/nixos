# 服务器角色基座
{ pkgs, user, ... }: {
  imports = [
    ../system/core.nix
    ../services/virt.nix
    ../dev/server.nix
    ../services/harmonia.nix
  ];

  home-manager.users.${user} = {
    imports = [ ../home/headless.nix ];
  };
}
