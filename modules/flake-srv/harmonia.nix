{ pkgs, lib, ... }:

let
  # 固定密钥（内部使用，直接内联）
  secretKeyFile = pkgs.writeText "harmonia-secret.key" ''
    harmonia-local:TgeMeagsZ0PPAvIpHp4JwzMMZtZpevbtT5wOdojkK9hsX/5GkQIlZtsTxbv+G7WNZGWRCq7/5xehWtYUQ2apdg==
  '';
in
{
  systemd.services.harmonia = {
    description = "Harmonia Nix binary cache";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "notify";
      ExecStart = lib.escapeShellArgs [
        "${pkgs.harmonia}/bin/harmonia-cache"
        "--config" (pkgs.writeText "harmonia.toml" ''
          store-dir = "/nix/store"
          bind = "[::]:5000"
          secret-key-files = "${secretKeyFile}"
          workers = 4
          max_connection_rate = 256
          priority = 50
        '')
      ];
      Restart = "on-failure";
      RestartSec = "5s";
      LimitNOFILE = 65536;
    };
  };
}
