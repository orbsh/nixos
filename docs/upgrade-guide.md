# NixOS 升级与迁移指南

本文档对比两种系统部署方案，并重点提供从 **Arch Linux 原地转换**到 NixOS 的实操步骤。

---

## 📋 核心结论：In-place 升级 (NIXOS_LUSTRATE) vs NixOS Anywhere

> **数据保留效果对比结论**：In-place 升级（NIXOS_LUSTRATE）在“保留当前根分区数据”方面更直接，通过 `/old-root` 机制避免格式化，是单分区系统迁移的最稳妥方案；而 NixOS Anywhere 在“自动化和全新环境构建”上更强，但通常伴随全量格式化的风险。

| 维度 | In-place 升级 (NIXOS_LUSTRATE) | NixOS Anywhere |
|:---|:---|:---|
| **保留数据能力** | ⭐⭐⭐⭐⭐ **极强**。直接保留当前根分区指定目录。 | ⭐⭐ **较弱**。通常伴随格式化风险。 |
| **自动化程度** | ⭐⭐ 需手动执行安装命令和配置。 | ⭐⭐⭐⭐⭐ **极高**。一键远程部署。 |
| **适用场景** | 现有系统（如 Arch）平滑迁移至 NixOS，数据敏感。 | 全新服务器构建，批量部署，或不在乎数据清空。 |

**结论**：
- **In-place 升级 (NIXOS_LUSTRATE)**：核心优势是**保留当前根分区数据**。通过 `/etc/NIXOS_LUSTRATE` 机制，重启时自动将旧系统文件移入 `/old-root`，保留指定目录（如 `/home`）原位。**这是单分区系统（如 Arch Linux）原地迁移到 NixOS 的最稳妥方案**。
- **NixOS Anywhere**：核心优势是**自动化和全新环境构建**。通过 SSH 远程配合 disko 进行全量分区和格式化，适合全新部署或不在乎数据清空的服务器初始化场景。

---

## 🔧 Arch Linux 转 NixOS 原地升级指南

> **适用前提**：你目前使用的是 Arch Linux，希望通过“保留数据、原地转换”的方式迁移到 NixOS。
> **核心思路**：在 Arch 中安装 Nix → 借用 Nix 构建出 NixOS 系统文件 → 创建引导标志位 → 重启。重启后，系统会自动将 Arch 的旧文件移入 `/old-root`，而指定的数据目录将保留在原位。

### 步骤 1：备份（生死攸关）
虽然此方案较为稳妥，但涉及引导扇区和文件系统变动。
*   **务必备份** `.config`、数据库、重要个人文件等到外部存储。
*   确保磁盘有 **20%-30% 的剩余空间**（用于同时容纳新旧系统文件）。

### 步骤 2：在 Arch 中安装 Nix
我们需要利用 Nix 的工具来生成 NixOS 系统结构。

```bash
# 1. 安装 Nix 环境
sudo pacman -S nix

# 2. 启动服务
sudo systemctl enable --now nix-daemon

# 3. 将自己加入 nix 用户组（需重新登录生效）
sudo usermod -aG nix-users $(whoami)
```

### 步骤 3：准备 NixOS 配置文件
创建配置文件。注意保持 UID 一致（Arch 和 NixOS 默认通常都是 1000）。

```bash
# 生成硬件配置（会参考当前的 /etc/fstab）
sudo mkdir -p /etc/nixos
nixos-generate-config --root /
```

编辑 `/etc/nixos/configuration.nix`，重点关注以下部分：

```nix
{ config, pkgs, ... }: {
  imports = [ ./hardware-configuration.nix ];

  # 引导配置（根据你的实际情况选择）
  # 如果是 UEFI:
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiBoot = true;

  # 如果是 BIOS (GRUB):
  # boot.loader.grub.enable = true;
  # boot.loader.grub.device = "/dev/sda";

  # 必须包含你现在的用户，确保 UID 一致！
  users.users."你的用户名" = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    uid = 1000;
  };

  # 显卡驱动（如果是 NVIDIA，务必在此配置，否则重启可能无法进入桌面）
  # hardware.opengl.enable = true;
  # services.xserver.videoDrivers = [ "nvidia" ];

  # 磁盘加密 (LUKS) - 如有需要
  # boot.initrd.luks.devices.root = { ... };

  system.stateVersion = "26.05";
}
```

### 步骤 4：构建并安装系统
这一步会将 NixOS 的系统组件下载并构建到 `/nix/store`，但**不会**立即破坏你的 Arch 系统。

```bash
# 添加 NixOS 频道 (可选，视你的配置依赖而定)
sudo nix-channel --add https://nixos.org nixos
sudo nix-channel --update

# 执行安装
# --no-root-passwd 防止交互式报错，重启后配置密码或密钥
sudo $(nix-build '<nixpkgs/nixos>' -A config.system.build.nixos-install --no-out-link)/bin/nixos-install --root / --no-root-passwd
```

### 步骤 5：设置 LUSTRATE 标志（数据保留的关键）
这是最关键的一步，告诉 NixOS 哪些 Arch 的文件夹**不要**移走。

1.  **标记系统**：
    ```bash
    sudo touch /etc/NIXOS
    ```

2.  **设置白名单**：创建 `/etc/NIXOS_LUSTRATE` 文件。
    *   内容是你希望保留的**目录名**（**不要**加前缀 `/`）。

    ```bash
    sudo bash -c 'cat > /etc/NIXOS_LUSTRATE <<EOF
home
root
opt
srv
EOF'
    ```
    *   *提示：如果你有 `/data` 或 `/downloads` 等数据目录，也请加入列表。*

### 步骤 6：重启与验证
执行 `sudo reboot`。

**启动后发生了什么？**
1.  NixOS 内核启动，检测到 `/etc/NIXOS_LUSTRATE`。
2.  **未列入名单**的目录（如 `/usr`, `/var`, `/bin`, `/etc` 的旧内容）会被移动到 **`/old-root/`** 目录下“养老”。
3.  **列入名单**的目录（如 `/home`）保留原位，数据完好无损。
4.  `/nix` 目录作为新系统核心被保留。

进入系统后，你可以检查 `/home` 下的数据是否都在，并在确认无误后，手动清理 `/old-root`（如需要）。

---

## ⚠️ 避坑指南

1.  **磁盘加密 (LUKS)**：如果 Arch 使用了加密盘，务必在 `configuration.nix` 中正确配置，否则重启后找不到根分区。
2.  **独立 Home 分区**：如果你原本就有独立的 `/home` 分区，其实更简单——在 NixOS 安装配置中挂载该分区且不格式化即可，无需使用 `LUSTRATE`。
3.  **NVIDIA 显卡**：单分区环境通常共用 `/boot` 或内核模块，如果驱动没在配置里写对，重启后可能进不去图形界面。
4.  **空间检查**：再次提醒，新旧系统共存期间需要大量空间。

---

## 🌍 NixOS Anywhere 远程部署指南

NixOS Anywhere 允许你通过 SSH 将运行中的 Linux 系统（无论是否为 NixOS）替换为 NixOS。

### 场景一：服务器全新安装（推荐，全量格式化）
适用于新服务器或可以清空数据的机器。此方案最彻底、最自动化。

1.  **准备 disko 配置**：在 flake 中定义磁盘分区，使用 `disko` 工具自动格式化。
2.  **执行部署**：
    ```bash
    nix run github:nix-community/nixos-anywhere -- --flake .#your-host root@<IP>
    ```

### 场景二：现有系统迁移（保留数据分区）
适用于已有数据（如 `/home`, `/var`）且**有独立分区**的服务器。

⚠️ **风险警告**：默认情况下 NixOS Anywhere 会清空磁盘。要保留数据，必须在 `disko` 配置中**排除**数据分区，或仅对系统分区进行操作。

1.  **配置策略**：
    *   在 `disko` 中**仅定义系统分区**（如 `/` 和 `/boot`）。
    *   在 `configuration.nix` 中通过 `fileSystems` 挂载现有的数据分区（不要通过 disko 格式化它们）。
    *   **务必确认** `disko` 配置中没有包含数据分区的 `format` 操作。
2.  **执行部署**：
    *   同场景一。

---

## ⚠️ 关键注意事项

1.  **密码设置风险 (`--no-root-passwd`)**：
    *   使用 `nixos-install` 或 `nixos-anywhere` 时，如果添加了 `--no-root-passwd` 参数，Root 密码将为空。
    *   如果你没有配置 SSH 公钥登录，重启后将**无法登录系统**。请务必确保配置中包含你的 SSH 公钥，或者在配置中设置了初始密码。
2.  **用户配置写法**：
    *   推荐使用 `users.users.<name> = { ... };`。
    *   在某些覆盖配置（Overlays）或 Home-Manager 集成场景下，可能会看到 `users.extraUsers.<name>` 的写法，两者在逻辑上等效，但 `extraUsers` 常用于模块化合并。请确保你的用户定义语法正确且 UID 保持一致。

---

## 📚 官方文档与参考资料

*   **NIXOS_LUSTRATE 说明**: [NixOS Manual - Upgrading Notes](https://nixos.org/manual/nixos/stable/#sec-upgrading-notes)
*   **nixos-install 说明**: [NixOS Manual - Installation](https://nixos.org/manual/nixos/stable/#sec-installation)
*   **Arch Wiki**: [Nix](https://wiki.archlinux.org/title/Nix)
