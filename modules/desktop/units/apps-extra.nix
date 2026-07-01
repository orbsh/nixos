{ pkgs, ... }: {
  imports = [
    ./vivaldi.nix          # 浏览器：Vivaldi + Chromium + 缩放修复
  ];

  environment.systemPackages = with pkgs; [

    # 媒体
    smplayer
    krita
    blender

    # 阅读
    calibre
    onlyoffice-desktopeditors
    zathura         # PDF 阅读
    foliate         # 电子书阅读

    # 工具
    peazip        # 压缩包管理（支持 200+ 格式）
    yt-dlp        # 视频/音频下载器
    ddgr          # DuckDuckGo 命令行搜索

    # 浏览器
    firefox

    # 以下按需取消注释：
    # lapce
    # bruno           # API 客户端
    # penpot-desktop
  ];

  # 移除工作站默认包集（含 nano 等），仅安装显式声明的包
  environment.defaultPackages = [];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkg.pname or "") [
      # "wps-office"        # 已移除
    ];
}
