{ config, pkgs, lib, inputs, user, ... }: {
  imports = [
    ./units/common.nix
    ./units/shell.nix
    ./units/editors.nix
    ./units/terminals.nix
    ./units/git.nix
    ./units/xdg.nix
    ./units/rime.nix
  ];

  home = {
    username = "${user}";
    homeDirectory = "/home/${user}";
  };

  # 工作站开发模式：符号链接 + git clone
  # TODO: 安装完成后切换回 true
  programs.nushell.developMode = true;

  # 让 home-manager 自己管理自己
  programs.home-manager.enable = true;
}
