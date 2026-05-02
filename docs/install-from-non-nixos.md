# 从第三方 Linux 系统安装 NixOS

本文档适用于在没有 NixOS 官方安装介质（USB Live CD）的情况下，直接从其他 Linux 发行版（如 Ubuntu, Arch, Debian 等）或已具备 Nix 包管理器的环境中，准备 NixOS 安装工具链并进行系统安装。

> **⚠️ 注意**：此流程仅在宿主机中提供安装所需的工具（如 `nixos-install`、`nixos-generate-config` 等），**不会**修改当前宿主机的系统配置。实际的 NixOS 系统将被安装到你指定的目标硬盘（通常挂载在 `/mnt`）。

## 步骤一：安装 Nix 包管理器

如果你的宿主机尚未安装 Nix，请先执行官方安装脚本。推荐使用多用户安装模式：

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

安装完成后，请**重新打开终端**或执行以下命令以确保环境变量生效：

```bash
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

## 步骤二：进入 NixOS 安装环境

使用 `nix shell` 获取 `nixos-install-tools`。这是一个包含 NixOS 安装核心工具的临时环境，不会干扰宿主机的文件系统。

```bash
nix --experimental-features "nix-command flakes" shell nixpkgs#nixos-install-tools
```

> **💡 提示**：
> - 执行该命令后，你的终端提示符可能会发生变化，表示已进入包含 `nixos-install` 等命令的 Shell 环境。
> - 如果提示找不到 `nixpkgs`，说明默认的 Flake 注册表未配置，请尝试使用完整路径：
>   ```bash
>   nix --experimental-features "nix-command flakes" shell github:NixOS/nixpkgs/nixos-unstable#nixos-install-tools
>   ```

## 步骤三：分区与安装系统

进入安装环境后，接下来的操作与从 Live USB 启动后的安装流程一致。你可以参考 [从便携系统盘安装 NixOS](./install-to-internal.md) 进行后续步骤：

1. **克隆配置**：将本项目的 NixOS 配置克隆到本地。
   ```bash
   git clone <你的仓库地址> ~/nixos-config
   cd ~/nixos-config
   ```

2. **分区与挂载**：
   - 使用 `lsblk` 确认目标硬盘设备名。
   - 使用 [disko](https://github.com/nix-community/disko) 进行分区和挂载：
     ```bash
     # 以项目中的 disko 配置为例（需根据实际硬件修改 disk.nix 中的设备路径）
     sudo nix run github:nix-community/disko -- --mode disko ./hosts/<目标主机>/disk.nix
     ```

3. **执行安装**：
   ```bash
   # 将配置安装到 /mnt
   sudo nixos-install --flake .#<主机名> --root /mnt

   # 设置 root 或用户密码
   sudo nixos-enter --root /mnt --command "passwd master"
   ```

4. **完成**：
   安装完成后，退出当前 Shell，卸载目标分区并重启：
   ```bash
   exit # 退出 nix shell
   sudo umount -R /mnt
   sudo reboot
   ```
