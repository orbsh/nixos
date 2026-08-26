{ config, lib, pkgs, user, ... }: {
  # 数据库客户端工具 + 数据分析 Python 库
  # 注：polars 等 python 库并入统一 python env（见 python.nix 的 programs.pythonEnv.extraPackages），
  #     不再自建 python3.withPackages 环境（避免多个同名 python3-env 竞争系统 python3 链接）。
  programs.pythonEnv.extraPackages = [
    pkgs.python3Packages.polars
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
  home-manager.users.${user} = {
    home.file.".duckdbrc" = {
      force = true;
      text = lib.concatStringsSep "\n" ([
      "SET extension_directory = '${config.home-manager.users.${user}.home.homeDirectory}/.duckdb/extensions';"
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
