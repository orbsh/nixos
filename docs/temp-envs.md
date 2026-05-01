# 临时程序与项目环境

本指南介绍如何临时运行工具，以及如何为项目创建独立开发环境。

## 临时安装运行程序（类似 LiveCD 或服务器临时调试）

在 NixOS 中，你可以不修改系统配置，临时运行某个程序。退出后该程序不会留在系统中。

### 方法 1：使用 `nix run`（推荐，Flake 风格）

```bash
# 直接运行 htop
nix run nixpkgs#htop

# 运行 btop
nix run nixpkgs#btop

# 运行树形查看器
nix run nixpkgs#broot
```

> 优点：自动下载并运行，无需安装到全局，用完即走。

### 方法 2：使用 `nix shell`（进入临时环境）

如果你需要连续使用多个工具，或者需要 shell 补全：
```bash
# 进入包含 htop、iotop、strace 的临时 shell
nix shell nixpkgs#htop nixpkgs#iotop nixpkgs#strace

# 退出后这些工具不再可用
exit
```

> **💡 提示：中途缺工具怎么办？**
> `nix shell` 启动后环境是固定的。如果临时发现少装了工具，**直接再次运行 `nix shell nixpkgs#新工具` 即可**。
> 这会进入一个“子环境”（嵌套），新旧工具都能使用。用完新工具后输入 `exit` 返回上一层。

### 方法 3：使用 `nix-shell -p`（传统方式）

```bash
# 临时开启包含 wget 和 curl 的环境
nix-shell -p wget curl
```

### ⚠️ LiveCD / 救援环境注意事项

在 LiveCD 或 chroot 环境中使用时，需注意以下两点：

1. **启用 flakes**：
   ```bash
   nix --experimental-features "nix-command flakes" run nixpkgs#htop
   ```

2. **sudo 路径**：
   NixOS 中 `sudo` 的实际路径为 `/run/wrappers/bin/sudo`（由 `security.sudo.enable = true` 生成的 setuid 包装器）。
   在 LiveCD、chroot 或最小化救援环境中，`/run/wrappers/bin/` 可能不在默认 `PATH` 中。若直接使用 `sudo` 提示 `command not found`，请改用完整路径：
   ```bash
   /run/wrappers/bin/sudo nixos-rebuild switch --flake .#workstation
   # 或临时导出 PATH
   export PATH="/run/wrappers/bin:$PATH"
   ```

