{ pkgs, lib, config, ... }:

{

  # wireshark 组 + dumpcap capability
  # 自动将所有 normal users 加入 wireshark 组
  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };
  users.groups.wireshark.members = lib.attrNames (
    lib.filterAttrs (name: user: user.isNormalUser or false) config.users.users
  );

  imports = [
    ./vivaldi.nix          # 浏览器：Vivaldi + Chromium + 缩放修复
    ./zed.nix              # 编辑器：Zed + IME 修复
  ];

  environment.systemPackages = with pkgs; [
    # Shell & 终端
    ghostty
    alacritty       # 备用终端

    # 编辑器（已移至 zed.nix）

    # 媒体播放
    nomacs
    qimgv
    mpv
    ffmpeg

    # 浏览器
    firefox
    chromium
    qutebrowser

    # 文件 & 办公
    freefilesync
    gparted

    # 截图
    flameshot

    # 桌面通知
    libnotify
  ];

  # programs.gparted.enable removed in newer nixpkgs; gparted still in environment.systemPackages

  # 移除工作站默认包集（含 nano 等），仅安装显式声明的包
  environment.defaultPackages = [];

  nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (pkg.pname or "") [
        "freefilesync"
      ];

  environment.variables = {
    EDITOR = "hx";
    VISUAL = "hx";
  };
}
