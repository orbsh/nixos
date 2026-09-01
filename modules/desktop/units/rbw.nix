# rbw: Unofficial Bitwarden CLI client
# https://github.com/doy/rbw
{ pkgs, lib, config, ... }:

{
  options.desktop.rbw = {
    src = lib.mkOption {
      type = lib.types.submodule {
        options = {
          url = lib.mkOption { type = lib.types.str; };
          narHash = lib.mkOption { type = lib.types.str; };
        };
      };
      default = {
        url = "http://box.d/nixos/rbw_1.15.0_linux_amd64.tar.gz";
        narHash = "sha256-HulxqTwSeB+//jIL0QsG25rYAEdZKvTqHjVexpvgjR4=";
      };
      description = "rbw 预编译包来源（指定 url 和 narHash）";
    };
  };

  config = let
    cfg = config.desktop.rbw;
    srcPath = (builtins.fetchTree {
      type = "tarball";
      inherit (cfg.src) url narHash;
    }).outPath;
  in {
    environment.systemPackages = [
      (pkgs.stdenv.mkDerivation {
        pname = "rbw";
        version = "1.15.0";

        src = srcPath;

        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        buildInputs = [ pkgs.stdenv.cc.cc.lib ];

        dontBuild = true;

        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin $out/share/bash-completion/completions $out/share/zsh/site-functions $out/share/fish/vendor_completions.d
          cp rbw rbw-agent $out/bin/
          chmod +x $out/bin/rbw $out/bin/rbw-agent
          cp completion/bash $out/share/bash-completion/completions/rbw
          cp completion/zsh $out/share/zsh/site-functions/_rbw
          cp completion/fish $out/share/fish/vendor_completions.d/rbw.fish
          runHook postInstall
        '';

        meta = with lib; {
          description = "Unofficial command line client for Bitwarden";
          homepage = "https://github.com/doy/rbw";
          license = licenses.mit;
          platforms = [ "x86_64-linux" ];
        };
      })
      # pinentry: rbw-agent 解锁密钥环时需要
      pkgs.pinentry-qt
    ];
  };
}
