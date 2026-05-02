# 从便携系统盘 (Portable) 安装 NixOS 到内置硬盘

本文档说明如何从 `portable` 系统盘（或任何已配置的 NixOS 环境），将 NixOS 安装到目标机器的内置硬盘上。

## 前置条件

- 已使用 `portable` 配置启动 USB 系统盘（包含完整图形界面和工具链）
- 已联网（通过 NetworkManager 或 `nmcli`）
- 目标硬盘无重要数据（**分区将清空整块磁盘**）

> **💡 提示：sudo 路径**
> 在 `portable` 系统中 `sudo` 通常已加入 PATH。若遇到 `command not found`，请使用 `/run/wrappers/bin/sudo` 或执行 `export PATH="/run/wrappers/bin:$PATH"`。

## 步骤一：准备工作区

由于 `portable` 系统是持久化的，且不像 ISO 那样自动挂载配置源码，你需要先将配置仓库克隆到本地：

```bash
# 克隆你的配置仓库
git clone <你的仓库地址> ~/nixos-config
cd ~/nixos-config
```

## 步骤二：确认硬盘设备名

```bash
lsblk -f
```

- `/dev/nvme0n1` — 内置 NVMe 固态硬盘
- `/dev/sda`     — SATA 硬盘
- `/dev/sdb`     — 你的 USB 系统盘（**请勿选错！**）

请根据容量确认目标硬盘，下文以 `/dev/nvme0n1` 为例。

## 步骤三：使用 disko 分区

本项目已集成 [disko](https://github.com/nix-community/disko)，可一键完成分区、格式化和挂载。

### 3.1 检查/编写 disko 配置

确保你的 `disko` 配置文件中的设备名与实际一致。
如果还没有独立的 disko 文件，可以创建一个临时的 `disk-config.nix`：

```nix
# disk-config.nix
{ device ? "/dev/nvme0n1", ... }: {
  disk = {
    main = {
      type = "disk";
      device = device;
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "512M";
            type = "EF00";
            content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; };
          };
          root = {
            size = "100%";
            content = { type = "filesystem"; format = "xfs"; mountpoint = "/"; };
          };
        };
      };
    };
  };
}
```

### 3.2 执行分区

```bash
# 格式化并自动挂载到 /mnt
sudo nix run github:nix-community/disko -- --mode disko ./disk-config.nix
```

> **💡 提示：安装中断后恢复**
> 若已分好区但安装中途暂停，下次继续时无需重新格式化，改用 `mount` 模式仅挂载：
> ```bash
> sudo nix run github:nix-community/disko -- --mode mount ./disk-config.nix
> ```

disko 会自动完成分区并将根文件系统挂载到 `/mnt`。

## 步骤四：安装 NixOS（含离线缓存选项）

### 4.1 选择安装模式

Portable ISO 通过 `cache.nix` 预置了大量包，安装时可优先使用 U 盘本地缓存，避免重复下载。

| 模式 | 命令参数 | 说明 |
|---|---|---|
| **纯离线** | `--option substitute false` | 仅使用 U 盘 `/nix/store` 中的包，缺失则报错 |
| **本地优先** | `--option substituters "file:///nix/store https://cache.nixos.org"` | 本地缺失时自动回退下载 |
| **默认** | 无额外参数 | 直接联网下载（可能重复拉取已有包） |

> **⚠️ 注意**：`--no-substitute` 参数在较新版本中已废弃，请使用 `--option substitute false` 替代。

### 4.2 执行安装

```bash
# 离线安装（推荐：当 cache.nix 已覆盖目标配置全部依赖时）
sudo nixos-install --flake ~/nixos-config#workstation --root /mnt --option substitute false

# 或本地优先 + 网络兜底（安全选项）
sudo nixos-install --flake ~/nixos-config#workstation --root /mnt \
  --option substituters "file:///nix/store https://cache.nixos.org"
```

### 4.3 设置用户密码

```bash
sudo nixos-enter --root /mnt --command "passwd master"
```

> **提示**：如果要安装服务器版，将 `#workstation` 替换为 `#server`。

## 步骤五：完成安装

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

# 4. 安装
sudo nixos-install --flake ~/nixos-config#workstation --root /mnt
```

## 常见问题

### Q: 安装时报错 `flake.cc:37: Assertion ... failed`？
这是 Nix flake 的 hash 断言错误，通常由 `flake.lock` 中的 narHash 与实际内容不匹配引起。常见于 Git 树有未提交更改时。

**解决方案：**
```bash
# 方案 1：确保所有更改已提交
git add -A && git commit -m "fix: ..."
nixos-install --flake ~/nixos-config#workstation --root /mnt

# 方案 2：临时跳过 lock file 写入（dirty tree 时的权宜之计）
nixos-install --flake ~/nixos-config#workstation --root /mnt --no-write-lock-file
```

### Q: 使用 `--option substitute false` 时报错 `path ... is not valid`？
说明 U 盘 ISO 的 `cache.nix` 中没有包含目标配置所需的某个包。

**解决方案：**
1. 改用本地优先模式，让缺失的包走网络下载：
   ```bash
   sudo nixos-install --flake ~/nixos-config#workstation --root /mnt \
     --option substituters "file:///nix/store https://cache.nixos.org"
   ```
2. 或在构建 ISO 前，将缺失的包添加到 `modules/iso/cache.nix` 中，重新构建 ISO。

### Q: 如何验证安装是否在使用本地缓存？
观察安装输出：
- 看到 `copying path '/nix/store/...'` → 从 U 盘本地复制
- 看到 `downloading from 'https://cache.nixos.org'` → 正在网络下载
- 使用 `--option substitute false` 时，若全程无 downloading 提示，即为纯离线安装。

### Q: 安装后无法从内置硬盘启动？
- 检查 BIOS/UEFI 启动顺序，确保内置硬盘在首位
- 确认 ESP 分区已正确挂载到 `/boot`
- 使用 portable U 盘启动后，重新运行 `nixos-install`（它会修复 bootloader）

### Q: disko 报错 "device is busy"？
- 确认目标硬盘没有被挂载：`umount /dev/nvme0n1*`
- 如果有 swap 或 LVM，先停用：`swapoff -a`、`vgchange -an`
