# 从外置硬盘 / U 盘安装 NixOS 到内置硬盘

本文档说明如何从已配置好的外置硬盘或 Live USB 环境，将 NixOS 安装到机器的内置硬盘上。

## 前置条件

- 已启动 NixOS Live 环境或从外置硬盘启动
- 已联网（或 ISO 已包含完整包缓存）
- 内置硬盘无重要数据（**分区将清空整块磁盘**）

## 步骤一：确认硬盘设备名

```bash
lsblk -f
```

- `/dev/nvme0n1` — 内置 NVMe 固态硬盘
- `/dev/sda`     — SATA 硬盘或 U 盘
- `/dev/mmcblk0` — eMMC 存储

请根据容量和类型确认哪块是目标内置硬盘，下文以 `/dev/nvme0n1` 为例。

## 步骤二：使用 disko 分区（推荐）

本项目已集成 [disko](https://github.com/nix-community/disko)，可一键完成分区、格式化和挂载。

### 2.1 使用预置配置

```bash
cd /mnt/etc/nixos  # 或你的 flake 所在路径

# 确认 disk-internal.nix 中的设备名与实际一致
cat hosts/workstation/disk-internal.nix

# 执行分区（--mode disko 会清空目标磁盘！）
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko ./hosts/workstation/disk-internal.nix
```

disko 会自动将分区挂载到 `/mnt`。

### 2.2 分区结构

| 分区 | 大小  | 格式 | 挂载点 |
|------|-------|------|--------|
| ESP  | 512M  | vfat | `/boot` |
| root | 100%  | xfs  | `/`     |

## 步骤三：安装 NixOS

```bash
# 使用 flake 安装（#workstation 替换为你的配置名）
sudo nixos-install --flake .#workstation --root /mnt

# 设置用户密码（在 chroot 环境中执行）
sudo nixos-enter --root /mnt
passwd master
exit
```

> **提示**：如果 flake 中尚未启用 `disk-internal.nix`，可临时通过命令行传入：
> ```bash
> sudo nixos-install --flake .#workstation \
>   --extra-experimental-features "nix-command flakes" \
>   --option extra-substituters "https://cache.nixos.org"
> ```

## 步骤四：安装完成

```bash
# 卸载并重启
sudo umount -R /mnt
reboot
```

重启后从 BIOS/UEFI 选择内置硬盘启动，验证系统是否正常。

## 附录 A：手动分区（备选）

如果不想使用 disko，可以手动操作：

```bash
# 1. 创建 GPT 分区表
sudo parted /dev/nvme0n1 -- mklabel gpt
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 513MiB
sudo parted /dev/nvme0n1 -- set 1 esp on
sudo parted /dev/nvme0n1 -- mkpart primary xfs 513MiB 100%

# 2. 格式化
sudo mkfs.vfat -F 32 /dev/nvme0n1p1
sudo mkfs.xfs -f /dev/nvme0n1p2

# 3. 挂载
sudo mount /dev/nvme0n1p2 /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/nvme0n1p1 /mnt/boot

# 4. 生成硬件配置
sudo nixos-generate-config --root /mnt
# 将生成的 hardware-configuration.nix 合并到你的 flake 中

# 5. 安装
sudo nixos-install --flake .#workstation
```

## 附录 B：完整克隆（外置系统 → 内置硬盘）

如果外置硬盘上的系统已经完全配置好，可以直接克隆：

```bash
# 1. 分区并格式化内置硬盘（同附录 A）

# 2. 使用 rsync 克隆根文件系统
sudo rsync -aAXv \
  --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} \
  / /mnt/

# 3. 重新生成 hardware-configuration.nix（UUID 已变更）
sudo nixos-generate-config --root /mnt

# 4. 更新 flake 中的硬件配置，然后重新安装 bootloader
sudo nixos-enter --root /mnt --command "nixos-rebuild boot"

# 5. 卸载并重启
sudo umount -R /mnt
reboot
```

## 常见问题

### Q: 安装后无法从内置硬盘启动？
- 检查 BIOS/UEFI 启动顺序，确保内置硬盘在首位
- 确认 ESP 分区已正确挂载到 `/boot`
- 重新运行 `nixos-rebuild boot` 或 `bootctl install`

### Q: disko 报错 "device is busy"？
- 确认目标硬盘没有被挂载：`umount /dev/nvme0n1*`
- 如果有 swap 或 LVM，先停用：`swapoff -a`、`vgchange -an`

### Q: 如何验证安装是否成功？
```bash
# 检查分区挂载
findmnt -t xfs,vfat

# 检查 bootloader
bootctl status

# 检查 flake 配置
nixos-rebuild build --flake .#workstation
```
