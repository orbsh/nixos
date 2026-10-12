{ ... }: {
  # MySQL 服务端（本地调试/独立部署用）
  # 默认使用 MySQL 8.0
  services.mysql = {
    enable = true;
    package = pkgs.mysql84;
  };
}
