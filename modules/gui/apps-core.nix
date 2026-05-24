{ pkgs, lib, config, dataDir, user, ... }: {

  # wireshark 组 + dumpcap capability
  # 自动将所有 normal users 加入 wireshark 组
  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };
  users.groups.wireshark.members = lib.attrNames (
    lib.filterAttrs (name: user: user.isNormalUser or false) config.users.users
  );

  environment.systemPackages = with pkgs; [
    # Shell & 终端
    ghostty
    alacritty       # 备用终端

    # 编辑器
    # neovim
    # neovide         # neovim GUI 前端
    zed-editor

    # 媒体播放
    nomacs
    qimgv
    mpv
    ffmpeg

    # 浏览器
    (pkgs.vivaldi.overrideAttrs (old: {
      src = builtins.path {
        path = "/home/${user}/pub/Application/Linux/vivaldi-stable_8.0.4033.34-1_amd64.deb";
        name = "vivaldi-stable_8.0.4033.34-1_amd64.deb";
      };
    }))
    firefox
    chromium
    qutebrowser

    # 文件 & 办公
    freefilesync
    gparted

    # 截图
    flameshot

  ];

  # programs.gparted.enable removed in newer nixpkgs; gparted still in environment.systemPackages

  # 移除工作站默认包集（含 nano 等），仅安装显式声明的包
  environment.defaultPackages = [];

  nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (pkg.pname or "") [
        "freefilesync"
        "vivaldi"
      ];

  environment.variables = {
    EDITOR = "hx";
    VISUAL = "hx";
  };
}
