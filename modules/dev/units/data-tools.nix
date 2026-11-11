{ config, lib, pkgs, user, ... }: {
  imports = [ ./duckdb.nix ];

  # 数据库客户端工具 + 数据分析 Python 库
  # 注：polars 等 python 库并入统一 python env（见 python.nix 的 programs.pythonEnv.extraPackages），
  #     不再自建 python3.withPackages 环境（避免多个同名 python3-env 竞争系统 python3 链接）。
  # pyiceberg: Iceberg catalog 操作；s3fs: S3 文件系统访问（pyiceberg 的 s3 表数据读写依赖它）
  # pyiceberg 的测试依赖链里挂着 pyspark（494MB）：nativeCheckInputs 的 geoarrow extra →
  # geopandas → mapclassify → scikit-learn → narwhals（其 nativeCheckInputs 含 pyspark）。
  # 这些只在跑测试时用，运行时不需要；清掉 checkInputs 才不会进构建图（只设 doCheck=false 仍会把它们算作 drv 输入）。
  programs.pythonEnv.extraPackages = with pkgs.python3Packages; [
    polars
    (pyiceberg.overridePythonAttrs (_: {
      doCheck = false;
      nativeCheckInputs = [ ];
    }))
    s3fs
  ];

  environment.systemPackages = [
    pkgs.postgresql
    # pkgs.mysql84
    pkgs.duckdb
  ];

  # DuckDB 配置（~/.duckdbrc），由 home-manager 托管
  # 与 hub.yaml 的 duckdb prepare/post 钩子保持一致：
  #   - SET 部分来自 post 钩子（共享扩展目录 + 自动 install/autoload）
  #   - INSTALL 列表来自 prepare 钩子，另加社区扩展 sshfs
  #     （社区扩展无法 autoload，需显式 INSTALL ... FROM community）
  # 2.0 起 extension_directory（单数）已弃用，改用 extension_directories（列表）。
  home-manager.users.${user} = {
    home.file.".duckdbrc" = {
      force = true;
      text = lib.concatStringsSep "\n" ([
      "SET extension_directories = ['${config.home-manager.users.${user}.home.homeDirectory}/.duckdb/extensions'];"
      "SET autoinstall_known_extensions = true;"
      "SET autoload_known_extensions = true;"
    ] ++ map (e: "INSTALL ${e};") [
      "httpfs"
      "delta"
      "ducklake"
      "iceberg"
      "lance"
      "postgres"
      "mysql"
      "sqlite"
      "fts"
      "sshfs FROM community"
    ]);
    };
  };
}
