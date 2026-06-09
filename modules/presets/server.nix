# 服务器角色基座
{ pkgs, user, ... }: {
  imports = [
    ../system/core.nix
    ../system/virt.nix
    ../dev/server.nix
    ../flake-srv/harmonia.nix
  ];

  home-manager.users.${user} = {
    imports = [ ../home/headless.nix ];
  };
}
