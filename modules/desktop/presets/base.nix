{ pkgs, ... }: {
  imports = [
    ../cosmic.nix
    ../input-method.nix
    ../fonts.nix
    ../eww.nix
    ../accessibility.nix
    ../fcitx5.nix
    ../apps-core.nix
  ];
}
