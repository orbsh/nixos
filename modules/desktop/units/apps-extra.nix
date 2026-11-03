{ pkgs, ... }: {
  imports = [
    ./vivaldi.nix          # 浏览器：Vivaldi + Chromium + 缩放修复
    ./blender.nix          # Blender：官方包，不带插件管理
    ./rustdesk.nix         # 远程桌面：GitHub 预编译二进制
  ];

  environment.systemPackages = with pkgs; [

    # 媒体
    #smplayer

    # 创作
    # krita
    # blender

    # 阅读
    # calibre              # 暂时禁用
    # gtk2 dependency is unused since 9.4.0: nixpkgs commit 133a1659 removes it, but the
    # pinned nixos-unstable rev predates it. Drop this override once the pin includes that commit.
    (onlyoffice-desktopeditors.override { gtk2 = pkgs.emptyDirectory; })
    zathura         # PDF 阅读
    foliate         # 电子书阅读

    # 工具
    yt-dlp        # 视频/音频下载器
    ddgr          # DuckDuckGo 命令行搜索
    rofi          # 应用启动器（原生支持 Wayland，rofi-wayland 已并入本包）

    # 浏览器
    #firefox

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
