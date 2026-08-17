# Open Interpreter: 让 LLM 在本地编写并执行代码（Python/JS/Shell 等）
# https://github.com/openinterpreter/openinterpreter
{ pkgs, lib, config, ... }:

{
  options.dev.openinterpreter = {
    src = lib.mkOption {
      type = lib.types.submodule {
        options = {
          url = lib.mkOption { type = lib.types.str; };
          narHash = lib.mkOption { type = lib.types.str; };
        };
      };
      default = {
        # 占位：实际使用前请将 zst 包加入 nix store 并填入真实 narHash
        # nix-store --add-fixed sha256 open-interpreter-package-x86_64-unknown-linux-musl.tar.zst
        # nix hash path /nix/store/xxx-...tar.zst
        url = "file:///nix/store/a8xyjjf0kldf8vn4z025ii7llvwf0q7v-open-interpreter-package-x86_64-unknown-linux-musl.tar.zst";
        narHash = "sha256-x8JwDlbaMD0fzIAPCUHUaGLQK7eftALquokbubt6ryw=";
      };
      description = "Open Interpreter 预编译包来源（rust 分支 release）";
    };
  };

  config = let
    cfg = config.dev.openinterpreter;
  in {
    environment.systemPackages = with pkgs; [
      bubblewrap  # bwrap：Codex/jcode 沙箱执行所需

      (stdenv.mkDerivation {
        pname = "open-interpreter";
        version = "latest";

        src = builtins.fetchTree {
          type = "file";
          inherit (cfg.src) url narHash;
        };

        nativeBuildInputs = with pkgs; [
          autoPatchelfHook
          zstd
        ];

        buildInputs = with pkgs; [
          stdenv.cc.cc.lib
          openssl
        ];

        dontBuild = true;
        dontUnpack = true;

        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin
          tar --zstd -xf $src -C $out/bin --strip-components=1 bin/interpreter
          mv $out/bin/interpreter $out/bin/open-interpreter
          ln -s open-interpreter $out/bin/oi
          chmod +x $out/bin/open-interpreter
          runHook postInstall
        '';

        meta = with lib; {
          description = "Open Interpreter — 让 LLM 在本地编写并执行代码";
          homepage = "https://github.com/openinterpreter/openinterpreter";
          license = licenses.agpl3Only;
          platforms = [ "x86_64-linux" ];
        };
      })
    ];
  };
}
