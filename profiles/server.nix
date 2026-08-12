# 服务器角色基座
{ pkgs, lib, user, ... }: {
  imports = [
    # 核心系统预设 + Home Manager 配置
    ../modules/system/core.nix

    ../modules/dev/server.nix

    ../modules/services/virt.nix
    ../modules/services/harmonia.nix
  ];

  # 服务器更新慢：只按代保留（50 代），不按时间清理，保留完整回滚能力
  nix.gc.keepGenerations = lib.mkForce 50;
  nix.gc.deleteOlderThan = lib.mkForce null;

  # 禁用 home-manager 的 neovim 模块（nixpkgs 25.11 中 neovimUtils.makeVimPackageInfo 已移除）
  # neovim 由系统级 NixOS 配置提供，插件由 lazy.nvim 管理
  home-manager.users.${user} = {
    programs.neovim.enable = lib.mkForce false;
  };
}
