{ pkgs, ... }: {
  services.nomad = {
    enable = true;
    package = pkgs.nomad;

    # 服务器作为 Nomad Server + Client 运行，管理集群并执行任务
    server.enable = true;
    client.enable = true;

    extraConfig = ''
      data_dir = "/opt/nomad/data"

      server {
        enabled = true
        bootstrap_expect = 1
      }

      client {
        enabled = true
        options = {
          "driver.exec.enabled"   = "true"
          "driver.podman.enabled" = "true"
        }
      }

      plugin "podman" {
        config {
          allow_privileged = true
        }
      }
    '';
  };
}