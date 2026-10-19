{ ... }: {
  imports = [
    ./units/direnv.nix
    ./units/python.nix
    ./units/rust.nix
    ./units/c-cpp.nix
    ./units/nodejs.nix
    ./units/haskell.nix
    ./units/data-tools.nix
    ./units/net-tools.nix
    ./units/k8s.nix
    ./units/wasm.nix
    # ../legacy/dev/units/zed.nix   # 已禁用（Zed 编辑器）
    ./units/jcode.nix
    # moli 已上移为基础工具（modules/system/units/moli.nix，见 system/units/extra.nix）
    # ../legacy/dev/units/emacs.nix  # 默认禁用，需在 host 定义中显式引入
    # 服务端（按需：容器化/独立部署场景取消注释）
    # ../legacy/dev/units/mysql-server.nix
    # ./units/postgresql-server.nix
    # ../legacy/dev/units/surrealdb-server.nix
  ];
}
