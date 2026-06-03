{ pkgs, lib, config, ... }:

{
  options.nushell.musl = {
    src = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          url = lib.mkOption { type = lib.types.str; };
          narHash = lib.mkOption { type = lib.types.str; };
        };
      });
      default = null;
      description = "Nushell musl 二进制文件来源（指定 url 和 narHash）。设置后启用 overlay 替换 nixpkgs 版本。";
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
          version = "0.0.0";

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
