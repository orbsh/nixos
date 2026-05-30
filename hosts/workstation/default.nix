{ inputs, lib, pkgs, ... }: {
  imports = [
    ./existing-disk.nix  # 现有磁盘挂载配置（不格式化）
    # ./disk.nix  # disko 重新分区格式化配置（按需启用）

    inputs.disko.nixosModules.disko

    ./hardware-configuration.nix           # 始终导入：内核模块等非磁盘硬件配置
    ../../modules/system/sys.nix
    ../../modules/system/base.nix
    ../../modules/system/nix.nix
    ../../modules/system/users.nix
    ../../modules/system/network.nix
    ./wireguard.nix
    ../../modules/system/container.nix
    ../../modules/system/extra.nix

    ../../modules/desktop/desktop.nix
    ../../modules/desktop/laptop.nix
    ../../modules/desktop/accessibility.nix    # 禁用无障碍语音播报
    ../../modules/desktop/apps-core.nix
    ../../modules/desktop/apps-extra.nix
    ../../modules/system/vm.nix            # libvirtd/virt-manager 虚拟机支持

    ../../modules/dev
    ../../modules/podman/mihomo.nix        # 代理容器
    ../../modules/podman/gitea.nix         # Gitea + PostgreSQL
    ../../modules/podman/miniflux.nix      # Miniflux RSS + PostgreSQL
    ../../modules/flake-srv/hermes-system.nix  # Hermes Agent: systemd 守护 + 全局 CLI 包裹
    ../../modules/desktop/apps-im.nix        # 即时通讯
  ];

  # ── 通用硬件支持 ──────────────────────────────────
  # 启用非自由固件与所有可能的固件，最大化对不同主板、WiFi、GPU 的兼容性
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;

  # 使用最新内核以获得更好的硬件驱动支持
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;

  # ── 文件系统支持 ──────────────────────────────────
  # 安装盘需能读写目标机器的各类分区
  boot.supportedFilesystems = [ "ntfs" "exfat" "ext4" "btrfs" "xfs" "vfat" ];

  # ── 网络与存储管理 ────────────────────────────────
  # NetworkManager 提供通用的网络配置能力
  networking.networkmanager.enable = true;

  # ── 性能与体验 ───────────────────────────────────
  # 启用 zram 交换，提升低内存环境下的响应速度
  zramSwap.enable = true;

  # 快速启动，不等待用户选择
  boot.loader.timeout = 5;

  wayland.windowManager.hyprland.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

  networking.hostName = "workstation";

  # ── Fcitx5 休眠唤醒后自动重启 ────────────────────────
  # COSMIC 锁屏 SIGKILL 输入法 Applet 导致 Wayland IM 断联。
  # 系统级 resume hook 通过 runuser 触发用户级 fcitx5 重启。
  powerManagement.resumeCommands = ''
    ${pkgs.systemd}/bin/runuser -u master -- ${pkgs.procps}/bin/pkill -f fcitx5 || true
    sleep 1
    ${pkgs.systemd}/bin/runuser -u master -- ${pkgs.fcitx5}/bin/fcitx5 -d || true
  '';
}
