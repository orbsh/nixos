{ pkgs, ... }: {

  # 自定义 target：所有使用 app-net 的容器都依赖此 target
  systemd.targets.podman-app-network = {
    description = "Podman custom network initialization target";
    unitConfig = {
      # 网络 init 服务完成后，此 target 即视为完成
      Requires = [ "podman-network-init.service" ];
      After = [ "podman-network-init.service" ];
    };
  };

  # app-net 桥接接口的 DNS 放行（与 podman0 默认桥接一致）
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -i podman1 -p udp --dport 53 -j nixos-fw-accept
  '';

  # 网络初始化服务
  systemd.services.podman-network-init = {
    description = "Create podman custom network (app-net)";
    script = ''
      ${pkgs.podman}/bin/podman network create \
        --subnet 10.89.0.0/24 \
        --gateway 10.89.0.1 \
        app-net 2>/dev/null || true
    '';
    wantedBy = [ "multi-user.target" ];
  };
}
