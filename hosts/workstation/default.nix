{ inputs, ... }: {
  imports = [
    inputs.disko.nixosModules.disko

    ./hardware-configuration.nix
    ../../modules/common/sys.nix
    ../../modules/common/base.nix
    ../../modules/common/users.nix
    ../../modules/common/network.nix
    ../../modules/common/container.nix
    ../../modules/common/extra.nix

    ../../modules/workstation/desktop.nix
    ../../modules/workstation/apps-core.nix
    ../../modules/workstation/apps-im.nix           # 微信单独管理
    ../../modules/workstation/extra.nix
    ../../modules/workstation/nomad.nix             # Nomad Client（开发调试）
    ../../modules/workstation/dev.nix
    # ../../modules/workstation/disk.nix  # 使用 hardware-configuration.nix 方案
  ];

  networking.hostName = "workstation";
  system.stateVersion = "25.05";
}