{ inputs, user, lib, pkgs, ... }: {
  imports = [
    ./existing-disk.nix  # 现有磁盘挂载配置（不格式化）
    # ./disk.nix  # disko 重新分区格式化配置（按需启用）

    inputs.disko.nixosModules.disko

    ./hardware-configuration.nix           # 始终导入：内核模块等非磁盘硬件配置
    # ── 核心系统预设 (sys, base, nix, users, network, extra, container) ──
    ../../modules/system/core.nix
    ../../modules/system/units/hardware-generic.nix  # 通用硬件配置
    ./wireguard.nix
    ../../modules/system/units/vm.nix            # libvirtd/virt-manager 虚拟机支持

    ../../modules/desktop/full.nix

    ../../modules/dev/fullstack.nix
    ../../modules/podman/full.nix      # Podman 全家桶 (代理 + 代码托管 + RSS)
    ../../modules/flake-srv/hermes-system.nix  # Hermes Agent: systemd 守护 + 全局 CLI 包裹
  ];

  # ── 用户环境配置 ──────────────────────────────────────
  home-manager.users.${user} = {
    imports = [
      ../../modules/home/desktop.nix
    ];
  };

  wayland.windowManager.hyprland.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

  networking.hostName = "workstation";
}
