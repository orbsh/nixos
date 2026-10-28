{ pkgs, lib, config, ... }:

let
  # 原始定义：官方 musl 二进制的固定钉。
  # 下面 version / url / hash 三行由 scripts/upstream.yml 的 nushell 条目自动改写（host 可覆盖）。
  pinned = {
    version = "0.116.1";
    url = "http://box.d/k8s/nu-0.116.1-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-E+913wjfMPjXsDHfU46CpSxudM6DmxqQkcOj8ZacN0I=";
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
          hash = lib.mkOption { type = lib.types.str; };
        };
      });
      default = { inherit (pinned) url hash; };
      description = ''
        Nushell musl 二进制来源（原始定义在模块的 pinned）。置 null 则回到 nixpkgs 版本。
        url + hash（flat sha256）构成固定输出 derivation：store 里已有该产物就跳过下载，
        可以随 drv 闭包推到别的机器，不像 builtins.fetchTree 那样依赖本机 fetcher 缓存。
      '';
    };
  };

  config = let
    cfg = config.nushell.musl;
  in {
    nixpkgs.overlays = lib.optional (cfg.src != null)
      (final: prev: {
        nushell = prev.stdenv.mkDerivation {
          pname = "nushell";
          version = cfg.version;

          # 固定输出 derivation（FOD）。用 builtins.fetchTree 会在 eval 期取物，
          # 命中与否取决于本机 ~/.cache/nix/fetcher-cache 的 URL 记录，换台机器照样下载；
          # FOD 的判定是 isValidPath(output)，所以推过去就不必再取。
          src = prev.fetchurl { inherit (cfg.src) url hash; };

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