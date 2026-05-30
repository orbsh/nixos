{ config, pkgs, user, ... }:

/*
╔══════════════════════════════════════════════════════════╗
║              KVM / libvirtd 虚拟机日常操作               ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  启动服务：                                              ║
║    sudo systemctl start libvirtd                         ║
║    sudo systemctl enable libvirtd                        ║
║                                                          ║
║  图形化管理（推荐）：                                    ║
║    virt-manager                                          ║
║                                                          ║
║  常用 virsh 命令：                                       ║
║    virsh list --all          # 列出所有虚拟机              ║
║    virsh start <vm>          # 启动虚拟机                  ║
║    virsh shutdown <vm>       # 优雅关机                    ║
║    virsh destroy <vm>        # 强制关机                    ║
║    virsh undefine <vm>       # 删除虚拟机定义              ║
║    virsh edit <vm>           # 编辑 XML 配置               ║
║    virsh console <vm>        # 串口控制台                  ║
║    virsh dominfo <vm>        # 查看虚拟机信息              ║
║                                                          ║
║  创建 Linux 虚拟机：                                     ║
║    virt-install --name arch --memory 4096 --vcpus 4 \   ║
║      --disk size=40 --cdrom /path/to/arch.iso \          ║
║      --os-variant archlinux --network default             ║
║                                                          ║
║  创建 Windows 虚拟机（需 UEFI + TPM）：                   ║
║    virt-install --name win11 --memory 8192 --vcpus 4 \  ║
║      --disk size=80 --cdrom /path/to/win11.iso \         ║
║      --cdrom ${pkgs.virtio-win}/share/virtio-win/drivers.iso \║
║      --os-variant win11 --network default \              ║
║      --tpm backend.type=emulator,backend.version=2.0 \   ║
║      --boot uefi                                          ║
║                                                          ║
║  Windows 驱动 ISO 路径：                                 ║
║    ${pkgs.virtio-win}/share/virtio-win/virtio-win.iso   ║
║                                                          ║
║  直通 GPU / USB 设备（VFIO）：                           ║
║    1. 内核参数添加：boot.kernelParams = [                  ║
║         "amd_iommu=on" "vfio-pci.ids=XXXX:XXXX"           ║
║       ];                                                  ║
║    2. boot.kernelModules = [ "vfio" "vfio_iommu_type1"   ║
║         "vfio_pci" "vfio_virqfd" ];                       ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
*/

{
  # 1. 开启 libvirtd 虚拟化服务
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;   # Win11 must
    };
  };

  # 2. 加载 KVM 虚拟化内核模块 (自动检测 AMD/Intel)
  boot.kernelModules = [
    "kvm-amd"
    "kvm-intel"
  ];

  # 3. 将用户加入组，免 sudo 管理 virsh
  users.users.${user}.extraGroups = [ "libvirtd" "kvm" ];

  # 4. 安装必要的命令行工具
  environment.systemPackages = with pkgs; [
    virt-manager        # 图形化管理工具
    libguestfs          # 提供 virt-install, virt-resize 等工具
    libvirt             # 提供 virsh 命令
    virt-viewer         # 用于连接 GUI 画面 (SPICE)
    virtio-win          # Windows 驱动 ISO
  ];

  # 5. 可选：开启内置的简单桌面显示支持
  services.spice-vdagentd.enable = true;
}
