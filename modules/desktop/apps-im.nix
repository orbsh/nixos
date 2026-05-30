{ pkgs, user, ... }:

let
  localPkg = import ../../libs/local-pkg.nix { inherit pkgs user; };
in {
  environment.systemPackages = with pkgs; [
    telegram-desktop
    # (localPkg { pkg = wechat; filename = "WeChatLinux_x86_64.AppImage"; })
    feishu
  ];

  nixpkgs.config.allowUnfree = true;
}
