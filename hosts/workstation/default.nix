{ inputs, lib, ... }: {
  imports = [
    ./existing-disk.nix  # 现有磁盘挂载配置（不格式化）
    # ./disk.nix  # disko 重新分区格式化配置（按需启用）

    inputs.disko.nixosModules.disko

    ./hardware-configuration.nix  # 始终导入：内核模块等非磁盘硬件配置
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
    ../../modules/workstation/apps-extra.nix

    ../../modules/dev
  ];

  # 启用 Hyprland 并禁用 COSMIC Greeter 以使用 SDDM
  wayland.windowManager.hyprland.enable = true;
  services.displayManager.cosmic-greeter.enable = false;

  # 启用完整开发工具链
  dev.enable = true;

  networking.hostName = "workstation";
}