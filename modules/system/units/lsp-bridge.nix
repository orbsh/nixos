# lsp-bridge.nix
# 服务端：lsp-bridge Python 运行时
# 不包含各语言的 lsp-server（按需单独安装）
{ config, pkgs, user, ... }:

let
  lspBridgePython = pkgs.python3.withPackages (ps: with ps; [
    epc orjson sexpdata six
    watchdog packaging
  ]);
in {
  environment.systemPackages = [
    lspBridgePython
    pkgs.git
  ];

  home-manager.users.${user} = {
    imports = [
      ({ config, lib, ... }: {
        home.activation.lspBridgeClone = config.lib.dag.entryAfter [ "linkGeneration" ] ''
          if [ ! -d "$HOME/lsp-bridge" ]; then
            ${pkgs.git}/bin/git clone --depth 1 https://github.com/manateelazycat/lsp-bridge.git "$HOME/lsp-bridge"
          fi
        '';
      })
    ];
  };
}
