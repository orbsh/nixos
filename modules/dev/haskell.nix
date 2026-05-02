{ pkgs, lib, config, ... }:

let
  cfg = config.dev.haskell;
in {
  options.dev.haskell.enable = lib.mkEnableOption "Haskell 开发工具链";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      haskellPackages.ghc
      haskellPackages.cabal-install
      haskellPackages.stack
      haskellPackages.haskell-language-server
    ];
  };
}