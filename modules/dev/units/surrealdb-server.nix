{ pkgs, lib, config, ... }:

{
  options.surrealdb.server = {
    version = lib.mkOption {
      type = lib.types.str;
      description = "SurrealDB 版本号";
      example = "3.2.0";
    };

    tarball = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "预编译二进制 tarball 源。格式：{ url = \"file:///...\"; sha256 = \"...\"; }";
      example = {
        url = "file:///home/master/pub/Application/Linux/surreal-v3.2.0.linux-amd64.tgz";
        sha256 = "nAqa4pRE87FEoSYfySMRaw4Qo8utxHjKvJAJs765uzo=";
      };
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 18000;
      description = "SurrealDB 监听端口";
    };

    enable = lib.mkEnableOption "SurrealDB 服务端";
  };

  config = let
    cfg = config.surrealdb.server;
    srcPath = (builtins.fetchTarball {
      inherit (cfg.tarball) url sha256;
    });
  in lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev: {
        surrealdb = prev.stdenv.mkDerivation {
          pname = "surrealdb";
          inherit (cfg) version;
          src = srcPath;
          dontUnpack = true;
          nativeBuildInputs = [ prev.autoPatchelfHook ];
          buildInputs = [ prev.libgcc.lib ];
          installPhase = ''
            mkdir -p $out/bin
            cp $src/surreal $out/bin/surreal
            chmod +x $out/bin/surreal
          '';
        };
      })
    ];

    environment.systemPackages = [ pkgs.surrealdb ];

    systemd.services.surrealdb = {
      description = "SurrealDB Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "surrealdb";
        Group = "surrealdb";
        ExecStart = "${pkgs.surrealdb}/bin/surreal start --bind 0.0.0.0:${toString cfg.port} --log info rocksdb:/var/lib/surrealdb";
        Restart = "on-failure";
        StateDirectory = "surrealdb";
        StateDirectoryMode = "0750";
      };
    };

    users.users.surrealdb = {
      isSystemUser = true;
      group = "surrealdb";
    };

    users.groups.surrealdb = {};
  };
}
