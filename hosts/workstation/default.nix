{ inputs, lib, pkgs, ... }: {
  imports = [
    ./existing-disk.nix  # 现有磁盘挂载配置（不格式化）
    # ./disk.nix  # disko 重新分区格式化配置（按需启用）

    inputs.disko.nixosModules.disko

    ./hardware-configuration.nix           # 始终导入：内核模块等非磁盘硬件配置
    # ── 核心系统预设 (sys, base, nix, users, network, extra, container) ──
    ../../modules/system/presets/core.nix
    ../../modules/system/hardware-generic.nix  # 通用硬件配置
    ./wireguard.nix
    ../../modules/system/vm.nix            # libvirtd/virt-manager 虚拟机支持

    ../../modules/desktop/presets/full.nix

    ../../modules/dev
    ../../modules/podman/mihomo.nix        # 代理容器
    ../../modules/podman/gitea.nix         # Gitea + PostgreSQL
    ../../modules/podman/miniflux.nix      # Miniflux RSS + PostgreSQL
    ../../modules/flake-srv/hermes-system.nix  # Hermes Agent: systemd 守护 + 全局 CLI 包裹
  ];

  wayland.windowManager.hyprland.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

  networking.hostName = "workstation";
}
