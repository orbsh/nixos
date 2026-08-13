{ pkgs, ... }:

{
  imports = [
    #./feishu.nix
    ./wechat.nix
  ];

  environment.systemPackages = with pkgs; [
    #telegram-desktop
  ];
}
