{ dataDir, user, ... }: {
  virtualisation.oci-containers.containers = {
    aria2 = {
      image = "p3terx/aria2-pro";
      environment = {
        "PUID" = "1000";
        "PGID" = "1000";
        "UMASK" = "002";
        "TZ" = "Etc/UTC";
        "LISTEN_PORT" = "6888";
        "RPC_SECRET" = "aria2-secret-token-change-me";
      };
      volumes = [
        "/home/${user}/data/aria2:/config"
        "/home/${user}/Downloads/aria2:/downloads"
      ];
      ports = [
        "6800:6800"    # RPC
        "6888:6888"    # BT listen (TCP)
        "6888:6888/udp" # BT listen (UDP)
      ];
      autoStart = true;
    };
  };

  systemd.services.podman-aria2 = {
    preStart = ''
      mkdir -p /home/${user}/data/aria2
      mkdir -p /home/${user}/Downloads/aria2
    '';

    after = [ "podman-app-network.target" ];
    requires = [ "podman-app-network.target" ];

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
