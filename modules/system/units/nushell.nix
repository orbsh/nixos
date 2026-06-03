{ pkgs, lib, config, ... }:

{
  options.nushell.musl = {
    src = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Nushell musl 二进制文件路径。设置后启用 overlay 替换 nixpkgs 版本。";
    };
  };

  config = let
    cfg = config.nushell.musl;
  in {
    nixpkgs.overlays = lib.optional (cfg.src != null)
      (final: prev: {
        nushell = prev.stdenv.mkDerivation {
          pname = "nushell";
          version = "0.0.0";

          src = prev.runCommand "nu.tar.gz" {}
            ''
              ln -s ${cfg.src} $out
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
