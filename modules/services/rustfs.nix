{ pkgs, lib, config, user, ... }:

let
  cfg = config.services.rustfs;
  dataDir = "/home/${user}/.rustfs-data";
  accessKeyFile = pkgs.writeText "rustfs-access-key" "iguZgGU9KqF2yA0oFGmk";
  secretKeyFile = pkgs.writeText "rustfs-secret-key" "uJKKnwI1sTtqaZIJCx75z9nmK5O3aUNg4Esz1ZQJ";
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

  config = {
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
  };
}
