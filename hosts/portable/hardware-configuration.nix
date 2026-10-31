{ config, lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # ── 通用存储与硬件支持 ──────────────────────────────────
  # 涵盖 SATA, NVMe, USB, VirtIO 等常见控制器，确保在各类主机上可引导
  boot.initrd.availableKernelModules = [
    "ata_piix"    # VirtualBox / 旧式 SATA
    "ahci"        # 标准 SATA 控制器
    "nvme"        # NVMe SSD
    "sd_mod"      # SCSI 磁盘支持
    "sr_mod"      # CD-ROM 支持
    "usb_storage" # USB 存储设备
    "uas"         # USB Attached SCSI
    "virtio_pci"  # 虚拟机 VirtIO 支持
    "virtio_blk"  # 虚拟机 VirtIO 磁盘
    "xhci_pci"    # USB 3.0 控制器
    "thunderbolt"  # Thunderbolt 接口支持（扩展坞、外置设备等）
    "usbhid"       # USB 输入设备（键盘、鼠标等）
    "sdhci_pci"    # 内置 SD 卡读卡器控制器
  ];

  # 注意：portable 作为 USB 移动系统盘，启动时 USB 设备枚举慢（USB 3.0 初始化、分区表读取）。
  # 历史上靠禁用 systemd initrd、退回 scripted initrd 规避（commit 44da8c8 启用 systemd initrd 导致
  # 启动失败，详见 ADR-010）。nixpkgs 已移除 scripted initrd，该选项不再存在，现只能走 systemd initrd，
  # 因此改为放宽设备等待时间：systemd 默认 DefaultDeviceTimeoutSec=90s，慢速 USB 枚举可能不够。
  boot.initrd.systemd.settings.Manager.DefaultDeviceTimeoutSec = "180s";

  # 初始 RAM 磁盘所需的内核模块
  boot.initrd.kernelModules = [ "dm-snapshot" ];

  # 宿主机内核模块（启用 KVM 虚拟化加速）
  boot.kernelModules = [ "kvm-intel" "kvm-amd" ];

  # 额外内核模块包
  boot.extraModulePackages = [ ];

  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

}
