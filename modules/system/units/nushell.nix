{ pkgs, lib, config, ... }:

let
  # 原始定义：官方 musl 二进制的固定钉。
  # 下面 version / url / narHash 三行由 scripts/upstream.yml 的 nushell 条目自动改写（host 可覆盖）。
  pinned = {
    version = "0.116.1";
    url = "http://box.d/k8s/nu-0.116.1-x86_64-unknown-linux-musl.tar.gz";
    narHash = "sha256-w9qBxjdu/Re2+VfM6yxFOu648FyTtwo0L94u13VwhVM=";
  };
in {
  options.nushell.musl = {
    version = lib.mkOption {
      type = lib.types.str;
      default = pinned.version;
      description = "musl 二进制的版本号（原始定义在模块的 pinned，tools 自动改写；host 可覆盖）";
    };

    src = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          url = lib.mkOption { type = lib.types.str; };
          narHash = lib.mkOption { type = lib.types.str; };
        };
      });
      default = { inherit (pinned) url narHash; };
      description = "Nushell musl 二进制文件来源（原始定义在模块的 pinned）。置 null 则回到 nixpkgs 版本。";
    };
  };

  config = let
    cfg = config.nushell.musl;
    srcPath = if cfg.src != null
      then (builtins.fetchTree {
        type = "file";
        inherit (cfg.src) url narHash;
      }).outPath
      else null;
  in {
    nixpkgs.overlays = lib.optional (srcPath != null)
      (final: prev: {
        nushell = prev.stdenv.mkDerivation {
          pname = "nushell";
          version = cfg.version;

          src = prev.runCommand "nu.tar.gz" {}
            ''
              ln -s ${srcPath} $out
            '';

          installPhase = ''
            mkdir -p $out/bin
            cp nu $out/bin/
            cp nufmt $out/bin/ 2>/dev/null || true
          '';

          doCheck = false;
          doInstallCheck = false;

          meta = {
            description = "A new type of shell (official musl binary)";
            homepage = "https://nushell.sh";
            license = prev.lib.licenses.mit;
            platforms = prev.lib.platforms.linux;
          };
        };
      });
  };
}