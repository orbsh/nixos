{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    surrealist        # SurrealDB GUI 客户端


    wps-office
    zathura         # PDF 阅读
    zathura-pdf-mupdf
    foliate         # 电子书阅读

    # 以下按需取消注释：
    # lapce
    # bruno           # API 客户端
    # penpot-desktop
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (pkg.pname or "") [
      "wps-office"
    ];
}
