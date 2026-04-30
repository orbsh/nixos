# 工作站安装与桌面配置指南

本文档涵盖 COSMIC 桌面工作站的安装流程、保留现有分区的方式，以及桌面环境的配置说明。

---

## 📦 工作站安装流程

### 场景选择

| 场景 | 说明 | 适用情况 |
|------|------|----------|
| **全新安装** | 使用 disko 格式化整个磁盘 | 新机器或可清空数据的场景 |
| **保留分区安装** | 手动分区，不执行 disko | 已有数据和分区的工作站（推荐） |

---

### 方式 A：保留现有分区（推荐）

大多数工作站已有分区和数据，**不要使用 disko**，直接生成硬件配置即可。

#### 1. 准备安装介质

**方式 A-1：使用官方 ISO**
从 [NixOS 官网](https://nixos.org/download/) 下载 ISO，放入 Ventoy U 盘启动。

**方式 A-2：使用自定义 ISO（推荐）**
```bash
# 在项目根目录构建自定义 ISO
nix build .#iso

# 将 ISO 复制到 Ventoy U 盘即可
cp result/iso/my-nixos-live.iso /mnt/ventoy/
```

> **Ventoy 使用方式：** 只需将 Ventoy 安装到 U 盘一次，之后直接将 ISO 文件拷贝到 U 盘中即可启动，无需重复写入。

#### 2. 确认现有分区

```bash
sudo -i
lsblk
lsblk -f  # 查看 UUID 和文件系统类型
```

记录以下信息：
- `/`（根分区）的设备名和 UUID
- `/boot`（EFI 分区）的设备名和 UUID
- `/home`（如独立分区）的设备名和 UUID

#### 3. 挂载现有分区

```bash
# 挂载根分区
mount /dev/sdXn /mnt

# 挂载 EFI 分区（如有）
mount /dev/sdYn /mnt/boot

# 挂载 home 分区（如有独立分区）
mount /dev/sdZn /mnt/home
```

> ⚠️ **重要：** 不要执行 `mkfs` 或 disko，避免格式化现有数据！

#### 4. 生成硬件配置

```bash
nixos-generate-config --root /mnt
```

该命令会自动扫描 `/mnt` 下的分区 UUID 并生成 `hardware-configuration.nix`。

请将生成的内容覆盖到 `hosts/workstation/hardware-configuration.nix`。

#### 5. 同步配置文件

```bash
# 将整个配置目录复制到 /mnt/etc/nixos
cp -r /path/to/this/repo/Configuration/nixos/* /mnt/etc/nixos/
```

#### 6. 安装系统

```bash
# 安装工作站（包含 COSMIC 桌面）
nixos-install --root /mnt --flake /mnt/etc/nixos#workstation

# 设置 root 密码
passwd

# 卸载并重启
umount -R /mnt
reboot
```

---

### 方式 B：全新安装（清空磁盘）

仅适用于新机器或可清空所有数据的场景。

#### 1. 应用 disko 分区

```bash
sudo -i
lsblk

# 应用磁盘配置（会清空磁盘！）
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko .#workstation
```

#### 2. 生成并安装

```bash
nixos-generate-config --root /mnt
# 覆盖 hosts/workstation/hardware-configuration.nix

cp -r /path/to/this/repo/Configuration/nixos/* /mnt/etc/nixos/

nixos-install --root /mnt --flake /mnt/etc/nixos#workstation
passwd
umount -R /mnt
reboot
```

---

## 🔄 从 Arch Linux 迁移

如果你目前使用的是 Arch Linux，希望保留数据和桌面环境迁移到 NixOS，请参阅 **[docs/upgrade-guide.md](./upgrade-guide.md)** 中的 **Arch Linux 原地升级指南**。

核心思路：在 Arch 中安装 Nix → 构建 NixOS 系统 → 设置 `/etc/NIXOS_LUSTRATE` 白名单 → 重启后自动保留 `/home` 等数据目录。

---

## 🖥️ 桌面环境说明

工作站默认配置了 **COSMIC Desktop Environment** 及相关工具链。

### 预装组件

| 类别 | 内容 |
|------|------|
| **桌面环境** | COSMIC DE (System76 新一代桌面) |
| **输入法** | fcitx5 + 中文支持 |
| **字体** | Noto Sans CJK、Source Han Sans 等 |
| **核心应用** | Ghostty 终端、Zed 编辑器、浏览器、媒体播放器 |
| **开发工具** | Rust、Haskell、Bun、Python、WASM、C/C++ 工具链 |
| **通讯工具** | 微信 (wechat-uos) |
| **办公套件** | WPS Office、Zathura PDF 阅读器 |

### 日常使用

COSMIC 桌面启动后即可使用，所有开发工具已随系统安装，无需额外配置：

```bash
# Rust 开发
cargo new my-project && cd my-project
cargo build

# Bun/Node.js 开发
bun init
bun add react react-dom

# Python 开发（uv 管理）
uv init
uv add fastapi uvicorn
```

### Home Manager 配置

用户级配置（dotfiles、GUI 应用设置）通过 Home Manager 管理，位于 `modules/home/workstation/`。

主要模块：
- `shell.nix` - Nushell 配置
- `editors.nix` - Helix/Neovim/Zed 配置
- `terminals.nix` - Ghostty + Zellij 配置
- `git.nix` - Git + lazygit + delta 配置
- `xdg.nix` - XDG 目录关联

更新 Home Manager 配置：
```bash
sudo nixos-rebuild switch --flake .#workstation
```

---

## ⚠️ 注意事项

### 硬件配置与分区

| 文件 | 用途 | 适用场景 |
|------|------|----------|
| `disk.nix` | 声明式磁盘分区（**执行时会格式化**） | 全新安装 |
| `hardware-configuration.nix` | 记录当前分区 UUID、挂载点、内核模块 | 所有主机（工作站通常仅依赖此项） |

- `hardware-configuration.nix` 由 `nixos-generate-config` 自动生成，**不应手动编辑**。
- **工作站通常已有分区**，直接使用 `hardware-configuration.nix`，**不要**导入 `disk.nix`。
- 更换硬件后，重新生成并覆盖 `hosts/workstation/hardware-configuration.nix`。

### 显卡驱动

NVIDIA 显卡用户务必在配置中启用专有驱动，否则可能无法进入图形界面：

```nix
# 在 modules/workstation/desktop.nix 或 hardware-configuration.nix 中
hardware.opengl.enable = true;
services.xserver.videoDrivers = [ "nvidia" ];
```

### 独立 Home 分区

如果你原本就有独立的 `/home` 分区：
1. 在 `hardware-configuration.nix` 中确保 `fileSystems."/home"` 配置正确
2. **不要**在 `disk.nix` 中定义 home 分区的格式化操作
3. 安装时直接挂载即可，数据会自动保留

### 占位符替换

使用前请修改以下占位符：

| 文件 | 占位符 | 说明 |
|------|--------|------|
| `modules/common/users.nix` | `ssh-ed25519 AAAA...` | 替换为你的 SSH 公钥 |
| `modules/home/git.nix` | `you@example.com` | 替换为你的 Git 邮箱 |
| `hosts/workstation/hardware-configuration.nix` | UUID 占位符 | 替换为实际磁盘 UUID |

---

## 📚 官方文档与参考资料

- [NixOS 官方手册](https://nixos.org/manual/nixos/stable/)
- [Flakes 文档](https://nixos.wiki/wiki/Flakes)
- [Home Manager 配置选项](https://nix-community.github.io/home-manager/options.xhtml)
- [COSMIC DE 文档](https://github.com/pop-os/cosmic-epoch)
- [NixOS 包搜索](https://search.nixos.org/packages)