{ pkgs, lib, config, ... }:

let
  prebuilt = import ../../../libs/prebuilt.nix { inherit pkgs lib; };

  # 原始定义：DuckDB 官方 CLI 二进制的固定钉。
  # 下面 version / url / hash 三行由 scripts/upstream.yml 的 duckdb 条目自动改写（host 可覆盖）。
  pinned = {
    version = "2.0.0";
    url = "http://box.d/nixos/duckdb-cli-2.0.0-linux-amd64.tar.gz";
    hash = "sha256-xlByBrr3eTxgE9vYI2hGmkXyDcDhem+S8gRgL2Uu0rw=";
  };
in {
  options.duckdb.prebuilt = prebuilt.mkPinOptions {
    inherit pinned;
    description = "DuckDB 官方 CLI 二进制来源（url + flat hash）";
  };

  config = let
    cfg = config.duckdb.prebuilt;
  in {
    nixpkgs.overlays = lib.optional (cfg.src != null) (final: prev: {
      # 官方 musl 版是动态链接（interpreter /lib/ld-musl-x86_64.so.1），NixOS 没这个 loader，
      # 执行直接报 cannot execute；所以取 glibc 版，用 autoPatchelfHook 改 interpreter 和 rpath。
      duckdb = prebuilt.mkPrebuilt {
        pname = "duckdb";
        version = cfg.version;
        src = cfg.src;

        nativeBuildInputs = [ prev.autoPatchelfHook ];
        buildInputs = [ prev.stdenv.cc.cc.lib ];

        # tarball 里只有一个 duckdb 文件、没有顶层目录，stdenv 推断不出 sourceRoot
        sourceRoot = ".";

        install = ''
          mkdir -p $out/bin
          install -m755 duckdb $out/bin/duckdb
        '';

        doCheck = false;
        doInstallCheck = false;

        updateScript = "duckdb";

        meta = {
          description = "DuckDB in-process SQL OLAP database (official prebuilt CLI)";
          homepage = "https://duckdb.org";
          license = prev.lib.licenses.mit;
        };
      };
    });
  };
}