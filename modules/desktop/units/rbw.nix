# rbw: Unofficial Bitwarden CLI client
# https://github.com/doy/rbw
{ pkgs, lib, config, ... }:

{
  options.desktop.rbw = {
    src = lib.mkOption {
      type = lib.types.submodule {
        options = {
          url = lib.mkOption { type = lib.types.str; };
          hash = lib.mkOption { type = lib.types.str; };
        };
      };
      default = {
        url = "http://box.d/nixos/rbw_1.15.0_linux_amd64.tar.gz";
        hash = "sha256-2BdLCurMvNgDIspB+0i/LbrY/E1dnFCcQru0bV4ZU5U=";
      };
      description = "rbw 预编译包来源（指定 url 和 flat hash）";
    };
  };

  config = let
    cfg = config.desktop.rbw;
    # FOD（fetchurl）：产物在 store 即跳过下载，可随闭包推送
    srcPath = pkgs.fetchurl { inherit (cfg.src) url hash; };
  in {
    environment.systemPackages = [
      (pkgs.stdenv.mkDerivation {
        pname = "rbw";
        version = "1.15.0";

        src = srcPath;

        # tarball 没有顶层目录，stdenv 的 sourceRoot 猜成 completion/ → 显式钉在解包根
        sourceRoot = ".";

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
