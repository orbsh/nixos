{ pkgs, lib, config, ... }:

let
  # 原始定义：DuckDB 官方 CLI 二进制的固定钉。
  # 下面 version / url / hash 三行由 scripts/upstream.yml 的 duckdb 条目自动改写（host 可覆盖）。
  pinned = {
    version = "2.0.0";
    url = "http://box.d/nixos/duckdb-cli-2.0.0-linux-amd64.tar.gz";
    hash = "sha256-xlByBrr3eTxgE9vYI2hGmkXyDcDhem+S8gRgL2Uu0rw=";
  };
in {
  options.duckdb.prebuilt = {
    version = lib.mkOption {
      type = lib.types.str;
      default = pinned.version;
      description = "DuckDB CLI 版本号（原始定义在模块的 pinned，upstream.nu 自动改写；host 可覆盖）";
    };

    src = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          url = lib.mkOption { type = lib.types.str; };
          hash = lib.mkOption { type = lib.types.str; };
        };
      });
      default = { inherit (pinned) url hash; };
      description = ''
        DuckDB 官方 CLI 二进制来源（原始定义在模块的 pinned）。置 null 则回到 nixpkgs 版本。
        url + hash（flat sha256）构成固定输出 derivation：store 里已有该产物就跳过下载，
        可以随 drv 闭包推到别的机器。
      '';
    };
  };

  config = let
    cfg = config.duckdb.prebuilt;
  in {
    nixpkgs.overlays = lib.optional (cfg.src != null)
      (final: prev: {
        # 官方 musl 版是动态链接（interpreter /lib/ld-musl-x86_64.so.1），NixOS 没这个 loader，
        # 执行直接报 cannot execute；所以取 glibc 版，用 autoPatchelfHook 改 interpreter 和 rpath。
        duckdb = prev.stdenv.mkDerivation {
          pname = "duckdb";
          version = cfg.version;

          # 固定输出 derivation（FOD）：判定靠 isValidPath(output)，推过去就不必再取。
          src = prev.fetchurl { inherit (cfg.src) url hash; };

          nativeBuildInputs = [ prev.autoPatchelfHook ];
          buildInputs = [ prev.stdenv.cc.cc.lib ];

          # tarball 里只有一个 duckdb 文件、没有顶层目录，stdenv 推断不出 sourceRoot
          sourceRoot = ".";

          installPhase = ''
            mkdir -p $out/bin
            install -m755 duckdb $out/bin/duckdb
          '';

          doCheck = false;
          doInstallCheck = false;

          meta = {
            description = "DuckDB in-process SQL OLAP database (official prebuilt CLI)";
            homepage = "https://duckdb.org";
            license = prev.lib.licenses.mit;
            platforms = prev.lib.platforms.linux;
            mainProgram = "duckdb";
          };
        };
      });
  };
}