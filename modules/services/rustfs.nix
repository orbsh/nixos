{ pkgs, lib, config, user, ... }:

let
  dataDir = "/home/${user}/.rustfs-data";
  accessKeyFile = pkgs.writeText "rustfs-access-key" "iguZgGU9KqF2yA0oFGmk";
  secretKeyFile = pkgs.writeText "rustfs-secret-key" "uJKKnwI1sTtqaZIJCx75z9nmK5O3aUNg4Esz1ZQJ";
in
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
        "RUSTFS_ADDRESS=:9000"
        "RUSTFS_ACCESS_KEY_FILE=${accessKeyFile}"
        "RUSTFS_SECRET_KEY_FILE=${secretKeyFile}"
        "RUSTFS_CONSOLE_ENABLE=true"
        "RUSTFS_CONSOLE_ADDRESS=:9001"
      ];
    };

    # 确保 volume 目录存在
    preStart = ''
      mkdir -p ${dataDir}
    '';
  };

  # 防火墙放行
  networking.firewall.allowedTCPPorts = [ 9000 9001 ];
}
