{ pkgs, ... }: {
  # 数据库客户端工具 + 数据分析 Python 环境
  environment.systemPackages = [
    pkgs.postgresql
    pkgs.mysql84
    pkgs.duckdb
    pkgs.surrealist

    # Data Science Python 库 (polars, lancedb)
    (pkgs.python3.withPackages (ps: with ps; [
      polars #lancedb
    ]))
  ];
}
