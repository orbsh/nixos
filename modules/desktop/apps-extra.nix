{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [

    # 媒体
    smplayer
    krita
    blender

    # 阅读
    calibre

    surrealist        # SurrealDB GUI 客户端


    onlyoffice-desktopeditors
    zathura         # PDF 阅读

    foliate         # 电子书阅读

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
