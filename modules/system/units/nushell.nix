{ pkgs, lib, config, ... }:

let
  prebuilt = import ../../../libs/prebuilt.nix { inherit pkgs lib; };

  # 原始定义：官方 musl 二进制的固定钉。
  # 下面 version / url / hash 三行由 scripts/upstream.yml 的 nushell 条目自动改写（host 可覆盖）。
  pinned = {
    version = "0.117.0";
    url = "http://box.d/k8s/nu-0.117.0-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-K4CHhtRK9BFwop+LmhW1ETu26l3akiEJjsqTL4oUmSQ=";
  };
in {
  options.nushell.musl = prebuilt.mkPinOptions {
    inherit pinned;
    description = "Nushell musl 二进制来源（url + flat hash）";
  };

  config = let
    cfg = config.nushell.musl;
  in {
    nixpkgs.overlays = lib.optional (cfg.src != null) (final: prev: {
      nushell = prebuilt.mkPrebuilt {
        pname = "nushell";
        version = cfg.version;
        src = cfg.src;

        install = ''
          mkdir -p $out/bin
          cp nu $out/bin/
          cp nufmt $out/bin/ 2>/dev/null || true
        '';

        doCheck = false;
        doInstallCheck = false;

        updateScript = "nushell";

        meta = {
          description = "A new type of shell (official musl binary)";
          homepage = "https://nushell.sh";
          license = prev.lib.licenses.mit;
        };
      };
    });
  };
}