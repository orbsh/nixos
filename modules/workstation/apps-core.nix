{ pkgs, ... }: {
  programs.nushell.enable = true;

  environment.systemPackages = with pkgs; [
    # Shell & 终端
    ghostty
    alacritty       # 备用终端

    # 编辑器
    neovim
    neovide         # neovim GUI 前端
    zed-editor

    # 浏览器
    vivaldi
    qutebrowser

    # 文件 & 办公
    freefilesync

    # 媒体
    smplayer
    krita
    blender


    # 截图
    flameshot

    # 阅读
    calibre
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkg.pname or "") [
      "vivaldi"
    ];

  environment.variables = {
    EDITOR = "hx";
    VISUAL = "hx";
  };
}
