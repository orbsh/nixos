{ pkgs, ... }: {
  services.nomad = {
    enable = true;
    package = pkgs.nomad;

    # 工作站作为完整的 Nomad 节点运行（Server + Client），支持本地开发与集群管理
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