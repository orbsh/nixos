{ pkgs, lib, ... }:

let
  # 固定密钥（内部使用，直接内联）
  secretKeyFile = pkgs.writeText "harmonia-secret.key" ''
    harmonia-local:TgeMeagsZ0PPAvIpHp4JwzMMZtZpevbtT5wOdojkK9hsX/5GkQIlZtsTxbv+G7WNZGWRCq7/5xehWtYUQ2apdg==
  '';
  configFile = pkgs.writeText "harmonia.toml" ''
    bind = "[::]:5000"
    sign_key_paths = ["${secretKeyFile}"]
    workers = 4
    max_connection_rate = 256
    priority = 50
  '';
in
{
  systemd.services.harmonia = {
    description = "Harmonia Nix binary cache";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    environment.CONFIG_FILE = configFile;

    serviceConfig = {
      Type = "notify";
      ExecStart = "${pkgs.harmonia}/bin/harmonia-cache";
      Restart = "on-failure";
      RestartSec = "5s";
      LimitNOFILE = 65536;
    };
  };
}
