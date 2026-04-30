{ inputs, ... }: {
  imports = [
    inputs.disko.nixosModules.disko

    ./hardware-configuration.nix
    ../../modules/common/sys.nix
    ../../modules/common/base.nix
    ../../modules/common/users.nix
    ../../modules/common/network.nix
    ./wireguard.nix
    ../../modules/common/container.nix
    ../../modules/common/extra.nix

    ../../modules/workstation/desktop.nix
    ../../modules/workstation/laptop.nix
    ../../modules/workstation/apps-core.nix
    ../../modules/workstation/apps-im.nix           # 微信单独管理
    ../../modules/workstation/extra.nix
    # ../../modules/workstation/nomad.nix             # Nomad Client（已废弃，services.nomad 在 nixpkgs 25.11 中被上游移除）
    ../../modules/workstation/dev.nix
    # ../../modules/workstation/disk.nix  # 使用 hardware-configuration.nix 方案

    # Podman 容器服务（Quadlet 替代方案，按需启用）
    # ../../modules/podman/mihomo.nix
  ];

  networking.hostName = "workstation";
}