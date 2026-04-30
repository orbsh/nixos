{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    surrealist        # SurrealDB GUI 客户端


    # wps-office        # 已从 nixpkgs 移除，可替换为 libreoffice 或 onlyoffice-bin
    zathura         # PDF 阅读

    foliate         # 电子书阅读

    # 以下按需取消注释：
    # lapce
    # bruno           # API 客户端
    # penpot-desktop
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkg.pname or "") [
      # "wps-office"        # 已移除
    ];
}
