{ pkgs, ... }: {
  imports = [
    ./units/cosmic.nix
    ./units/input-method.nix
    ./units/fonts.nix
    ./units/eww.nix
    ./units/accessibility.nix
    ./units/fcitx5.nix
    ./units/apps-core.nix
  ];
}
