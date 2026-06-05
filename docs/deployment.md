# NixOS 部署指南

本文档说明 NixOS 安装的原理与具体操作。关于项目的 host 结构与配置架构，参见 [README](../README.md)。

---

## 核心原理

NixOS 安装的本质是**将声明式配置转化为可启动系统**：

```
flake.nix (声明) → nixos-install (求值+构建) → /mnt (可启动系统)
```

关键区别：
- **传统 Linux**：安装器执行命令序列，状态不可复现
- **NixOS**：安装器求值 flake 输出，构建完整系统闭包，状态由配置决定

因此，"安装"只需做一次。之后的所有变更都是 `nixos-rebuild switch`，原理与安装完全一致。

---

## 阶段一：准备安装环境

需要获取包含 `nixos-install` 的运行环境。三种方式：

| 方式 | 适用场景 | 特点 |
|------|----------|------|
| **自定义 ISO** | 推荐，批量部署 | `nix build .#iso`，体积 ~781MB，包含离线缓存 |
| **官方 ISO** | 快速体验 | 从 nixos.org 下载，需联网下载所有包 |
| **宿主机 + nix** | 从现有 Linux 迁移 | 安装 Nix 后进入安装环境 |

### 构建自定义 ISO

```bash
nix build .#iso.config.system.build.isoImage
# 产物：result/iso/nixos-*.iso
```

将 ISO 写入 Ventoy U 盘即可启动。

### 从宿主机安装 Nix

如果从现有 Linux（如 Arch）迁移，无需制作 U 盘：

```bash
# 安装 Nix（daemon 模式）
sh <(curl -L https://nixos.org/nix/install) --daemon
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# 进入安装环境
nix --experimental-features "nix-command flakes" shell nixpkgs#nixos-install-tools
```

终端提示符变化后，即可使用 `nixos-install`。

### 离线缓存机制

自定义 ISO 预构建的包存储在 `/nix/store` 中。安装时通过 substituters 配置优先使用本地缓存：

```bash
# 本地优先，缺失时回退网络
sudo nixos-install --root /mnt --flake .#<host> \
  --option substituters "file:///nix/store https://cache.nixos.org"
```

| 参数 | 说明 |
|------|------|
| 无 | 默认从 cache.nixos.org 下载 |
| `--option substitute false` | 纯离线，缺失则报错 |
| `--option substituters "file:///nix/store ..."` | 本地优先，回退网络 |

验证缓存是否生效：
- 看到 `copying path '/nix/store/...'` → 从本地复制
- 看到 `downloading from 'https://...'` → 网络下载

---

## 阶段二：磁盘规划

### disko 原理

[disko](https://github.com/nix-community/disko) 将分区声明转化为可执行脚本：

```
disk.nix (声明) → disko 工具 → 分区 + 格式化 + 挂载到 /mnt
```

关键模式：
- `--mode disko`：执行分区和格式化（全新安装，**会清空磁盘**）
- `--mode mount`：仅挂载已有分区（保留数据）

### 确认目标磁盘

```bash
lsblk -f
```

常见设备名：
- `/dev/nvme0n1` — 内置 NVMe 固态硬盘
- `/dev/sda` — SATA 硬盘
- `/dev/sdb` — USB 系统盘（**请勿选错！**）

根据容量确认目标硬盘。下文以 `/dev/nvme0n1` 为例。

**⚠️ disk.nix 中的 device 必须指向整块磁盘，而非分区**：

```nix
# ✅ 正确：指向整块磁盘
device = "/dev/nvme0n1";
device = "/dev/disk/by-id/nvme-Samsung_970_EVO_XXX";

# ❌ 错误：指向分区（disko 会失败）
device = "/dev/nvme0n1p1";  # 分区而非磁盘
device = "/dev/sda1";        # 分区而非磁盘
```

确认设备类型：
```bash
# 查看设备是否为磁盘（TYPE=disk）而非分区（TYPE=part）
lsblk -d -o name,type | grep nvme0n1
# 输出：nvme0n1 disk

# 或使用 by-id 路径（推荐，更稳定）
ls -l /dev/disk/by-id/ | select name target
```

### 全新安装（清空磁盘）

```bash
# 已安装到系统中，直接使用
sudo disko --mode disko ./hosts/<host>/disk.nix
```

> **说明**：`disko` 已预装到系统（`modules/system/units/nix.nix`），无需 `nix run` 下载。

disk.nix 定义完整的分区布局：
- ESP 分区（vfat, 挂载到 `/boot`）
- 根分区（文件系统类型、子卷结构）
- 交换空间（可选）

### 保留数据分区

1. 确保 `disk.nix` 中目标分区设置 `noFormat = true` 或 `_create = false`
2. 使用 `--mode mount` 仅挂载：

```bash
sudo disko --mode mount ./hosts/<host>/disk.nix
```

**关键点**：disk.nix 是幂等的声明，但 `--mode disko` 执行时会格式化：
- 全新安装：用 `--mode disko`
- 保留数据：用 `--mode mount`，或确保 disk.nix 已配置 `noFormat`

### 安装中断后恢复

若已分好区但安装中途暂停，无需重新格式化：

```bash
sudo disko --mode mount ./hosts/<host>/disk.nix
```

---

## 阶段三：配置生成

### hardware-configuration.nix 的作用

此文件记录**当前硬件的实际状态**，由 `nixos-generate-config` 自动生成：

```
/mnt 下的挂载点 → 扫描 UUID → hardware-configuration.nix
```

生成的内容包括：
- 文件系统 UUID（从 `/mnt` 下的挂载点扫描）
- 内核模块（检测到的硬件驱动）
- 交换设备

**重要**：
- 此文件是**硬件快照**，不应手动编辑
- 更换硬件后必须重新生成
- 生成后需覆盖到对应的 host 目录

### 生成硬件配置

```bash
nixos-generate-config --root /mnt
```

该命令会在 `/mnt/etc/nixos/` 下生成：
- `configuration.nix` — 基础配置模板
- `hardware-configuration.nix` — 硬件配置

**⚠️ 与 disko 的冲突**：

`nixos-generate-config` 会扫描 `/mnt` 生成 `fileSystems` 定义，但 `disk.nix` (disko) 已经声明了同样的挂载点，导致重复定义。

**解决方案**：编辑生成的 `hardware-configuration.nix`，删除 `fileSystems` 和 `swapDevices` 部分（保留内核模块等其他内容）：

```nix
# 删除这些（disko 已处理）：
fileSystems."/" = { ... };
fileSystems."/boot" = { ... };
swapDevices = [ ... ];

# 保留这些：
boot.initrd.availableKernelModules = [ ... ];
boot.kernelModules = [ ... ];
```

**将生成的内容覆盖到 host 目录**：

```bash
# 示例：覆盖到 server 的配置
sudo cp /mnt/etc/nixos/hardware-configuration.nix ./hosts/server/
```

每个 host 的 `hardware-configuration.nix` 必须匹配该主机的实际硬件。

### 同步配置文件（可选）

`nixos-install` 支持直接从本地路径读取 flake，无需复制：

```bash
sudo nixos-install --root /mnt --flake .#<host>
```

> **注意**：如果从 Live CD 或其他环境安装，配置目录不在当前路径，则需要先复制：
> ```bash
> sudo cp -r ./* /mnt/etc/nixos/
> sudo nixos-install --root /mnt --flake /mnt/etc/nixos#<host>
> ```

---

## 阶段四：执行安装

### nixos-install 原理

```
nixos-install --root /mnt --flake .#<host>
```

执行流程：
1. **求值 flake**：读取当前目录的 flake.nix，找到 `nixosConfigurations.<host>`
2. **构建系统闭包**：根据配置生成所有需要的 Nix 包
3. **安装到 /mnt**：将闭包写入 `/mnt/nix/store`，生成 `/mnt/etc`、`/mnt/run` 等
4. **安装引导器**：根据 `boot.loader` 配置安装 systemd-boot 或 GRUB

### 执行安装命令

```bash
# 使用本地缓存 + 网络兜底
sudo nixos-install --root /mnt --flake .#<host> \
  --option substituters "file:///nix/store https://cache.nixos.org" \
  --option trusted-public-keys "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
```

**参数说明**：
- `--root /mnt`：安装目标目录
- `--flake /mnt/etc/nixos#<host>`：指定 flake 位置和 host 名称
- `--option substituters`：缓存源列表（本地优先）
- `--option trusted-public-keys`：缓存签名公钥

### 设置密码

**NixOS 密码机制：配置优先**

每次 `nixos-rebuild switch` 后，配置中定义的密码会覆盖手动设置的密码。手动设置只在以下场景有用：
- 首次安装后、首次 rebuild 前需要登录
- 配置中完全没有密码/SSH 密钥设置

如果配置中已设置 SSH 公钥或密码，可以跳过此步骤。

如果配置中未设置任何认证方式，安装后需要手动设置：

```bash
# 进入安装的系统
sudo nixos-enter --root /mnt

# 设置用户密码
passwd <username>

# 或设置 root 密码（服务器场景）
passwd

# 退出
exit
```

> **建议**：在配置中设置 SSH 公钥（推荐）或密码，避免安装后手动操作。参见 `modules/system/units/users.nix`。

### 卸载并重启

```bash
sudo umount -R /mnt
reboot
```

重启后从 BIOS/UEFI 选择目标硬盘启动，验证系统是否正常。

---

## 迁移方案

从现有系统迁移到 NixOS 时，根据数据保留需求选择：

| 方案 | 数据保留 | 自动化 | 适用场景 |
|------|----------|--------|----------|
| **NIXOS_LUSTRATE** | 强，保留指定目录 | 低，需手动执行 | 单分区系统，数据敏感 |
| **NixOS Anywhere** | 弱，通常格式化 | 高，一键远程 | 全新服务器，可清空数据 |

### NIXOS_LUSTRATE：原地迁移

**原理**：在现有系统中安装 Nix，构建 NixOS 系统到 `/nix/store`，然后设置 `/etc/NIXOS_LUSTRATE` 白名单。重启时：

1. NixOS 内核启动，检测 LUSTRATE 标志
2. 白名单外的目录（`/usr`、`/var` 等）移到 `/old-root/`
3. 白名单内的目录（如 `/home`）保留原位
4. `/nix` 目录作为新系统核心

**适用前提**：单分区系统，或 `/home` 与根分区在同一文件系统。

**操作步骤**：

```bash
# 1. 在现有系统（如 Arch）中安装 Nix
sudo pacman -S nix  # 或其他发行版的包管理器
sudo systemctl enable --now nix-daemon

# 2. 准备 NixOS 配置
sudo mkdir -p /etc/nixos
nixos-generate-config --root /
# 编辑 /etc/nixos/configuration.nix，配置用户、引导、显卡等

# 3. 构建 NixOS 系统（不会立即破坏现有系统）
sudo nixos-install --root / --no-root-passwd

# 4. 设置 LUSTRATE 标志
sudo touch /etc/NIXOS

# 5. 设置白名单（保留的目录名，不要加前缀 /）
sudo bash -c 'cat > /etc/NIXOS_LUSTRATE <<EOF
home
root
opt
srv
EOF'

# 6. 重启
sudo reboot
```

**避坑指南**：
- **磁盘加密 (LUKS)**：务必在配置中正确配置，否则重启后找不到根分区
- **NVIDIA 显卡**：驱动没配置对，重启后可能进不去图形界面
- **空间检查**：新旧系统共存期间需要 20-30% 剩余空间

### NixOS Anywhere：远程部署

**原理**：通过 SSH 连接目标机器，使用 disko 分区格式化，然后远程执行 `nixos-install`。

**操作步骤**：

```bash
# 在本地执行
nix run github:nix-community/nixos-anywhere -- --flake .#<host> root@<ip>
```

**适用前提**：
- 目标机器已运行 Linux，可通过 SSH 访问
- 可接受数据清空（或数据在独立分区且 disk.nix 已配置保留）

**保留数据的配置策略**：
- 在 `disk.nix` 中**仅定义系统分区**（如 `/` 和 `/boot`）
- 在 `configuration.nix` 中通过 `fileSystems` 挂载现有的数据分区
- **务必确认** disk.nix 中没有包含数据分区的 `format` 操作

---

## 常见问题

### Q: 安装后无法启动

检查：
1. BIOS/UEFI 启动顺序是否正确
2. ESP 分区是否挂载到 `/boot`
3. 从安装介质启动，重新运行 `nixos-install`（会修复引导器）

### Q: dirty tree 错误

`flake.cc:37: Assertion failed` 通常因为 Git 有未提交更改，导致 narHash 不匹配：

```bash
# 方案 1：提交更改
git add -A && git commit -m "fix: ..."

# 方案 2：跳过 lock file
nixos-install --flake .#<host> --root /mnt --no-write-lock-file
```

### Q: disko 报错 "device is busy"

确认目标磁盘未被挂载：

```bash
umount /dev/nvme0n1*
swapoff -a
vgchange -an  # 如有 LVM
```

### Q: 更新已安装的系统（外部挂载）

在 Live CD 或另一台机器上挂载目标磁盘到 `/mnt` 时，用 `nixos-install` 而非 `nixos-rebuild`：

```bash
sudo nixos-install --root /mnt --no-root-password --flake .#<host>
```

`--no-root-password` 避免重置已有系统的用户状态。

### Q: sudo 路径问题

NixOS 中 `sudo` 的实际路径为 `/run/wrappers/bin/sudo`。若环境中提示 `command not found`：

```bash
export PATH="/run/wrappers/bin:$PATH"
# 或使用完整路径
/run/wrappers/bin/sudo nixos-rebuild switch --flake .#<host>
```

---

## 参考资料

- [NixOS 官方手册 - 安装](https://nixos.org/manual/nixos/stable/#sec-installation)
- [disko 文档](https://github.com/nix-community/disko)
- [NIXOS_LUSTRATE 说明](https://nixos.org/manual/nixos/stable/#sec-upgrading-notes)
- [NixOS Anywhere](https://github.com/nix-community/nixos-anywhere)
