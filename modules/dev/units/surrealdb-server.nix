{ pkgs, lib, config, ... }:

{
  options.surrealdb.server = {
    version = lib.mkOption {
      type = lib.types.str;
      description = "SurrealDB 版本号";
      example = "3.1.4";
    };

    src = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "预编译二进制源。格式：{ url = \"file:///nix/store/...\"; narHash = \"sha256-...\"; }";
      example = {
        url = "file:///nix/store/xxx-surreal-v3.1.4.linux-amd64";
        narHash = "sha256-...";
      };
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "SurrealDB 监听端口";
    };

    enable = lib.mkEnableOption "SurrealDB 服务端";
  };

  config = let
    cfg = config.surrealdb.server;
    srcPath = (builtins.fetchTree {
      type = "file";
      inherit (cfg.src) url narHash;
    }).outPath;
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
            cp $src $out/bin/surreal
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
