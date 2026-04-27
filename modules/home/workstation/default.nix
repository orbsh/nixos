{ pkgs, lib, inputs, ... }: {
  imports = [
    ./shell.nix
    ./editors.nix
    ./terminals.nix
    ./git.nix
    ./xdg.nix
  ];

  home = {
    username = "master";
    homeDirectory = "/home/master";
    stateVersion = "26.05";
  };

  # 工作站开发模式：符号链接 + git clone
  programs.nushell.developMode = true;

  # 让 home-manager 自己管理自己
  programs.home-manager.enable = true;
}
