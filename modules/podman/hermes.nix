{ pkgs, dataDir, user, ... }: {
  virtualisation.oci-containers.containers = {
    hermes = {
      image = "ghcr.io/fj0r/xy:hermes";
      volumes = [
        "${dataDir}/hermes/.hermes:/opt/data"
      ];
      environment = {
        "HERMES_UID" = "1000";
        "HERMES_GID" = "1000";
      };
      extraOptions = [
        "--network=host"
      ];
      cmd = [ "gateway" "run" ];
      autoStart = true;
    };
  };

  systemd.services.podman-hermes = {
    preStart = ''
      mkdir -p ${dataDir}/hermes/.hermes
    '';

    unitConfig = {
      StartLimitBurst = 3;
      StartLimitIntervalSec = 60;
    };
    serviceConfig = {
      RestartSec = "10s";
      Restart = "on-failure";
    };
    wantedBy = [ "multi-user.target" "default.target" ];
  };
}
