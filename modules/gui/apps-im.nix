{ pkgs, ... }: {
  # WeChat（nix-community 维护的 wechat-uos）
  environment.systemPackages = with pkgs; [
    wechat-uos
    telegram-desktop
  ];

  # wechat-uos 需要这个
  nixpkgs.config.allowUnfree = true;
}
