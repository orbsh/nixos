{ config, pkgs, lib, inputs, user, ... }: {
  imports = [
    ./units/common.nix
    ./units/shell.nix
    ./units/editors.nix
    ./units/terminals.nix
    ./units/git.nix
    ./units/xdg.nix
    ./units/eww.nix
  ];

  home = {
    username = "${user}";
    homeDirectory = "/home/${user}";
  };

  # nushell 配置通过 flake input 部署
  programs.nushell.developMode = false;

  # 让 home-manager 自己管理自己
  programs.home-manager.enable = true;
}
