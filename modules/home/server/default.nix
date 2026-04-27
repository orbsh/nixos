{ pkgs, lib, inputs, ... }: {
  imports = [
    ./shell.nix
    ./editors.nix
    ./git.nix
  ];

  home = {
    username = "master";
    homeDirectory = "/home/master";
    stateVersion = "25.05";
  };

  # 让 home-manager 自己管理自己
  programs.home-manager.enable = true;
}
