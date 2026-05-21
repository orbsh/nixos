{ inputs, pkgs, lib, ... }: {
  imports = [
    #./existing-disk.nix
    ./existing-btrfs.nix  # 现有磁盘挂载配置（不格式化）
    # ./disk.nix  # disko 重新分区格式化配置（按需启用）

    inputs.disko.nixosModules.disko

    ./hardware-configuration.nix  # 始终导入：内核模块等非磁盘硬件配置

    # ── 通用基础模块 (与 ISO 保持一致，确保工具链完整) ──
    ../../modules/common/sys.nix
    ../../modules/common/base.nix
    ../../modules/common/nix-tools.nix
    ../../modules/common/users.nix
    ../../modules/common/network.nix
    ../../modules/common/container.nix
    ../../modules/common/extra.nix

    # ── 工作站桌面与应用模块 (使 portable 具备完整 GUI 和工具链) ──
    ../../modules/workstation/desktop.nix
    ../../modules/workstation/apps-core.nix
    # # ../../modules/workstation/apps-im.nix
    # ../../modules/workstation/apps-extra.nix
    ../../modules/dev
    # 注意：不包含 laptop.nix，避免在非笔记本硬件上报错
    ../../modules/common/vm.nix
    ../../modules/podman/mihomo.nix        # 代理容器
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
  # Use iwd as WiFi backend — more reliable than wpa_supplicant
  networking.networkmanager.wifi.backend = "iwd";
  # Disable WiFi power management to prevent connection drops
  networking.networkmanager.wifi.powersave = false;

  # udisks2 用于自动挂载可移动设备（方便访问目标硬盘或 U 盘数据）
  services.udisks2.enable = true;

  # ── 性能与体验 ───────────────────────────────────
  # 启用 zram 交换，提升低内存环境下的响应速度
  zramSwap.enable = true;

  # 快速启动，不等待用户选择
  boot.loader.timeout = 5;

  # 自动登录 master 用户，启动即用
  networking.hostName = "portable";
  services.getty.autologinUser = "master";

  # ── 图形界面配置 ──────────────────────────────────
  # wayland.windowManager.hyprland.enable = true;
  # services.displayManager.cosmic-greeter.enable = lib.mkForce false;
}
