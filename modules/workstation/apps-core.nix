{ pkgs, lib, config, ... }: {

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

    # 浏览器
    vivaldi
    firefox
    chromium
    qutebrowser

    # 文件 & 办公
    freefilesync

    # 截图
    flameshot

  ];

  # 移除工作站默认包集（含 nano 等），仅安装显式声明的包
  environment.defaultPackages = [];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkg.pname or "") [

      "vivaldi"
    ];

  environment.variables = {
    EDITOR = "hx";
    VISUAL = "hx";
  };
}
