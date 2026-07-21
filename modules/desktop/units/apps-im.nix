{ pkgs, user, ... }:

let
  localPkg = import ../../../libs/local-pkg.nix { inherit pkgs user; };

  # 飞书：禁用 Wayland 原生支持，回退 XWayland（避免缩放渲染问题）
  feishu-wayland = pkgs.symlinkJoin {
    name = "feishu-wayland";
    paths = [ pkgs.feishu ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/bytedance-feishu \
        --add-flags "--disable-features=UseOzonePlatform" \
        --add-flags "--ozone-platform=x11"
    '';
  };
in {
  imports = [
    ./wechat.nix
  ];

  environment.systemPackages = with pkgs; [
    #telegram-desktop
    feishu-wayland
  ];

  nixpkgs.config.allowUnfree = true;
}
