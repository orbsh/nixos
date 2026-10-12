{ pkgs, ... }:

{
  imports = [
    #../../legacy/desktop/units/feishu.nix
    ./wechat.nix
  ];

  environment.systemPackages = with pkgs; [
    #telegram-desktop
  ];
}
