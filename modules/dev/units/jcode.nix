# jcode: Ultra-fast Rust-based AI coding agent (Server/Client swarm architecture)
{ pkgs, lib, config, ... }:

{
  options.dev.jcode = {
    src = lib.mkOption {
      type = lib.types.submodule {
        options = {
          url = lib.mkOption { type = lib.types.str; };
          narHash = lib.mkOption { type = lib.types.str; };
        };
      };
      default = {
        url = "file:///nix/store/4apcza3yjbpnjzbm2y544ir307vqy49n-jcode-linux-x86_64.tar.gz";
        narHash = "sha256-D1Nqnwy0fzP6Qr5041aqh3jAvecq3Bcfrhs66Z2kGto=";
      };
      description = "jcode 预编译包来源";
    };
  };

  config = let
    cfg = config.dev.jcode;
  in {
    environment.systemPackages = [
      (pkgs.stdenv.mkDerivation {
        pname = "jcode";
        version = "latest";

        src = builtins.fetchTree {
          type = "tarball";
          inherit (cfg.src) url narHash;
        };

        nativeBuildInputs = with pkgs; [
          autoPatchelfHook
        ];

        buildInputs = with pkgs; [
          stdenv.cc.cc.lib
          openssl
        ];

        dontBuild = true;

        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin
          cp $src/jcode-linux-x86_64.bin $out/bin/jcode
          chmod +x $out/bin/jcode
          runHook postInstall
        '';

        meta = with lib; {
          description = "Next-gen ultra-fast Rust-based AI Agent Harness with multi-session swarm concurrency";
          homepage = "https://github.com/1jehuang/jcode";
          license = licenses.mit;
        };
      })
    ];
  };
}
