# rbw: Unofficial Bitwarden CLI client
# https://github.com/doy/rbw
{ pkgs, lib, config, ... }:

let
  prebuilt = import ../../../libs/prebuilt.nix { inherit pkgs lib; };
in {
  options.desktop.rbw = {
    src = prebuilt.mkSrcOption {
      nullable = false;
      default = {
        url = "http://box.d/nixos/rbw_1.15.0_linux_amd64.tar.gz";
        hash = "sha256-2BdLCurMvNgDIspB+0i/LbrY/E1dnFCcQru0bV4ZU5U=";
      };
      description = "rbw 预编译包来源（指定 url 和 flat hash）";
    };
  };

  config = let
    cfg = config.desktop.rbw;
  in {
    environment.systemPackages = [
      (prebuilt.mkPrebuilt {
        pname = "rbw";
        version = "1.15.0";
        src = cfg.src;

        # tarball 没有顶层目录，stdenv 的 sourceRoot 猜成 completion/ → 显式钉在解包根
        sourceRoot = ".";

        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        buildInputs = [ pkgs.stdenv.cc.cc.lib ];

        dontBuild = true;

        updateScript = "rbw";

        install = ''
          runHook preInstall
          mkdir -p $out/bin $out/share/bash-completion/completions $out/share/zsh/site-functions $out/share/fish/vendor_completions.d
          cp rbw rbw-agent $out/bin/
          chmod +x $out/bin/rbw $out/bin/rbw-agent
          cp completion/bash $out/share/bash-completion/completions/rbw
          cp completion/zsh $out/share/zsh/site-functions/_rbw
          cp completion/fish $out/share/fish/vendor_completions.d/rbw.fish
          runHook postInstall
        '';

        meta = {
          description = "Unofficial command line client for Bitwarden";
          homepage = "https://github.com/doy/rbw";
          license = lib.licenses.mit;
        };
      })
      # pinentry: rbw-agent 解锁密钥环时需要
      pkgs.pinentry-qt
    ];
  };
}