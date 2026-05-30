{ ... }: {
  imports = [
    ./units/python.nix
    ./units/rust.nix
    ./units/javascript.nix
    ./units/haskell.nix
    ./units/data-tools.nix
    ./units/net-tools.nix
    ./units/k8s.nix
    ./units/wasm.nix
    # 服务端（按需：容器化/独立部署场景取消注释）
    # ./units/mysql-server.nix
    # ./units/postgresql-server.nix
    # ./units/surrealdb-server.nix
  ];
}
