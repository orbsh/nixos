{ pkgs, lib, config, user, ... }:

let
  prebuilt = import ../../libs/prebuilt.nix { inherit pkgs lib; };

  cfg = config.services.rustfs;
  dataDir = "/home/${user}/.rustfs-data";
  accessKeyFile = pkgs.writeText "rustfs-access-key" "iguZgGU9KqF2yA0oFGmk";
  secretKeyFile = pkgs.writeText "rustfs-secret-key" "uJKKnwI1sTtqaZIJCx75z9nmK5O3aUNg4Esz1ZQJ";

  # 原始定义：rustfs 官方 release 二进制的固定钉。
  # 下面 version / url / hash 三行由 scripts/upstream.yml 的 rustfs 条目自动改写（host 可覆盖）。
  pinned = {
    version = "1.0.5";
    url = "http://box.d/nixos/rustfs-1.0.5-linux-x86_64-musl.zip";
    hash = "sha256-PZ1Cu0y3oViSZgkNT5+COEZVBs3Z1eiXGTN33W9hCqw=";
  };
in
{
  options.services.rustfs = {
    port = lib.mkOption {
      type = lib.types.int;
      default = 9000;
      description = "S3 兼容 API 监听端口";
    };
    consolePort = lib.mkOption {
      type = lib.types.int;
      default = 9001;
      description = "管理控制台监听端口";
    };
  };

  # 常设自维护：官方 release 二进制（static-pie 单文件，无运行时依赖，不需要 autoPatchelfHook）。
  # nixpkgs 的 rustfs 是源码包（47 个自研 crate），每次 nixpkgs bump 都可能被拖去本机全量编译；
  # 上游配方也漏过 pkg-config 导致 zstd-sys 构建必失败。二者相比下预编译是常设形态，不再计划回归 pkgs.rustfs。
  options.rustfs.prebuilt = prebuilt.mkPinOptions {
    inherit pinned;
    description = "rustfs 官方预编译压缩包来源（url + flat hash）";
  };

  config = lib.mkMerge [
    (lib.mkIf (config.rustfs.prebuilt.src != null) {
      nixpkgs.overlays = [
        (final: prev: {
          rustfs = prebuilt.mkPrebuilt {
            pname = "rustfs";
            version = config.rustfs.prebuilt.version;
            src = config.rustfs.prebuilt.src;

            dontUnpack = true;

            install = ''
              mkdir -p $out/bin
              ${prev.unzip}/bin/unzip -q $src -d .
              install -m755 rustfs $out/bin/rustfs
            '';

            doCheck = false;

            updateScript = "rustfs";

            meta = {
              description = "S3-compatible high-performance object storage (official prebuilt binary)";
              homepage = "https://github.com/rustfs/rustfs";
              license = prev.lib.licenses.asl20;
            };
          };
        })
      ];
    })

    {
      systemd.services.rustfs = {
        description = "Rustfs S3-compatible object storage";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.rustfs}/bin/rustfs server ${dataDir}";
          Restart = "on-failure";
          RestartSec = "5s";

          Environment = [
            "RUSTFS_ADDRESS=:${toString cfg.port}"
            "RUSTFS_ACCESS_KEY_FILE=${accessKeyFile}"
            "RUSTFS_SECRET_KEY_FILE=${secretKeyFile}"
            "RUSTFS_CONSOLE_ENABLE=true"
            "RUSTFS_CONSOLE_ADDRESS=:${toString cfg.consolePort}"
          ];
        };

        # 确保 volume 目录存在
        preStart = ''
          mkdir -p ${dataDir}
        '';
      };

      # 防火墙放行
      networking.firewall.allowedTCPPorts = [ cfg.port cfg.consolePort ];
    }
  ];
}