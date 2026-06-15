{ pkgs, ... }:

{
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
    chromium
    qutebrowser

    # 文件 & 办公
    freefilesync
    gparted

    # 截图
    flameshot

    # 桌面通知
    libnotify

    # 剪贴板
    wl-clipboard
  ];

  # programs.gparted.enable removed in newer nixpkgs; gparted still in environment.systemPackages

  # 移除工作站默认包集（含 nano 等），仅安装显式声明的包
  environment.defaultPackages = [];

  nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (pkg.pname or "") [
        "freefilesync"
      ];
}
