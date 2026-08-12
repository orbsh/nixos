# 核心系统预设 + Home Manager 基础配置
{ ... }: {
  imports = [
    ./units/sys.nix
    ./units/kanata.nix
    ./units/base.nix
    ./units/nix.nix
    ./units/gc.nix
    ./units/users.nix
    ./units/network.nix
    ./units/extra.nix
    ./units/container.nix
    ./units/nushell.nix
    ./units/systemd-compliance.nix
    ./units/hardware-generic.nix

    # Home Manager 基础（nvim、git、shell）
    ./units/home-base.nix
    ./units/home-shell.nix
    ./units/home-nvim.nix
    #./units/home-kakoune.nix
    ./units/home-git.nix
    ./units/lsp-bridge.nix
  ];
}
