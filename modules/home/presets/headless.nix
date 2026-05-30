{ config, pkgs, lib, inputs, user, ... }: {
  imports = [
    ../common.nix
    ../shell.nix
    ../editors.nix
    ../git.nix
  ];

  home = {
    username = "${user}";
    homeDirectory = "/home/${user}";
  };

  # 让 home-manager 自己管理自己
  programs.home-manager.enable = true;

  # 禁用 home-manager 的 neovim 模块（nixpkgs 25.11 中 neovimUtils.makeVimPackageInfo 已移除）
  # neovim 由系统级 NixOS 配置提供，插件由 lazy.nvim 管理
  programs.neovim.enable = lib.mkForce false;
}
