{ pkgs, user, ... }:

let
  localPkg = import ../../../libs/local-pkg.nix { inherit pkgs user; };
in {
  environment.systemPackages = with pkgs; [
    telegram-desktop
    wechat
    feishu
  ];

  nixpkgs.config.allowUnfree = true;
}
