# jcode: 轻量 Rust CLI Agent（14ms 冷启动，救援定位——Hermes 出问题时用它修 Hermes）
# https://github.com/1jehuang/jcode
{ pkgs, lib, config, ... }:

let
  prebuilt = import ../../../libs/prebuilt.nix { inherit pkgs lib; };
in {
  options.dev.jcode = {
    src = prebuilt.mkSrcOption {
      nullable = false;
      default = {
        # 包放 box.d/nixos/（同 open-interpreter 模式）；升级时：下载→更新 flat hash
        # curl -sL -o jcode.tar.gz http://box.d/nixos/jcode-linux-x86_64.tar.gz
        # nix hash file --type sha256 --sri jcode.tar.gz
        url = "http://box.d/nixos/jcode-linux-x86_64.tar.gz";
        hash = "sha256-CyphLel8bgGubeHAz/VVs0YM+DZNGhHS+GSfwMnXoeY=";
      };
      description = "jcode 预编译包来源（GitHub release，linux-x86_64）";
    };
  };

  config = let
    cfg = config.dev.jcode;
  in {
    environment.systemPackages = [
      (prebuilt.mkPrebuilt {
        pname = "jcode";
        version = "0.99.1";
        src = cfg.src;

        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        buildInputs = [ pkgs.stdenv.cc.cc.lib ];

        dontBuild = true;
        dontUnpack = true;

        updateScript = "jcode";

        install = ''
          runHook preInstall
          mkdir -p $out/bin
          # tar 内是 wrapper 脚本 + .bin 真 ELF；wrapper 按原始文件名找 .bin，不能改名
          tar -xzf $src -C $out/bin
          ln -s jcode-linux-x86_64 $out/bin/jcode
          runHook postInstall
        '';

        meta = {
          description = "jcode — 轻量 Rust CLI Agent（Server/Client 解耦，多会话并发）";
          homepage = "https://github.com/1jehuang/jcode";
          license = lib.licenses.mit;
        };
      })
    ];
  };
}