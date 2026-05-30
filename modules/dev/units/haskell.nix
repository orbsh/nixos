{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    haskellPackages.ghc
    haskellPackages.cabal-install
    haskellPackages.stack
    haskellPackages.haskell-language-server
  ];
}
