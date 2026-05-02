{ config, lib, ... }:

let
  cfg = config.dev.databases;
in {
  options.dev.databases = {
    enable = lib.mkEnableOption "常用开发数据库服务（默认禁用）";

    postgresql = {
      enable = lib.mkEnableOption "启用 PostgreSQL 数据库服务";
    };
    surrealdb = {
      enable = lib.mkEnableOption "启用 SurrealDB 数据库服务";
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql.enable = lib.mkDefault cfg.postgresql.enable;
    services.surrealdb.enable = lib.mkDefault cfg.surrealdb.enable;
  };
}