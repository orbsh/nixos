# 日常操作流程

本指南涵盖了 NixOS 系统的日常维护、更新与清理操作。

## flake.lock 说明

`flake.lock` 是 Nix Flakes 的**锁定文件**（类似 `package-lock.json`），记录每个输入依赖的精确 commit hash 和 narHash。

| 命令 | 作用 | 下载包？ | 验证配置？ |
|------|------|----------|------------|
| `nix flake lock` | 锁定输入版本到精确 commit | ❌ | ❌ |
| `nix flake update` | 更新所有输入到最新版本并重新锁定 | ❌ | ❌ |
| `nix flake check` | 检查 flake outputs 是否合法 | ✅ (仅检查用) | ✅ 基本语法 |
| `nixos-rebuild dry-build` | 模拟重建（不实际切换） | ✅ | ✅ 完整验证 |
| `nixos-rebuild switch` | 重建并切换到新配置 | ✅ | ✅ 完整验证 |

**重要：** `nix flake lock` 和 `nix flake update` **只解析依赖版本，不下载任何缓存包**，也**不验证你的 NixOS 配置是否正确**。

## 更新系统

```bash
### 标准更新流程（推荐）

```bash
# 1. 更新 lock 文件（只锁定版本，不下载包）
nix flake update

# 2. 验证配置能否成功构建（不实际切换，会下载必要依赖）
sudo nixos-rebuild dry-build --flake .#workstation

# 3. 确认无误后切换
sudo nixos-rebuild switch --flake .#workstation
```

### 快速更新（跳过验证）

```bash
# 更新 flake 输入（拉取最新 nixpkgs）
nix flake update

# 重建并切换（不重启）
sudo nixos-rebuild switch --flake .#workstation

# 重建并重启（内核更新时必须）
sudo nixos-rebuild switch --flake .#workstation --upgrade
```

## 切换世代与回滚

```bash
# 查看已安装的世代
nix-env --list-generations --profile /nix/var/nix/profiles/system

# 运行时回滚到上一世代
sudo nix-env --rollback --profile /nix/var/nix/profiles/system
```

## 清理垃圾

```bash
# 删除未被当前世代引用的包
sudo nix-collect-garbage -d

# 删除旧世代（保留最近 5 个）
sudo nix-env --delete-generations old --profile /nix/var/nix/profiles/system

# 优化 Nix Store
sudo nix optimise-store
```

## 搜索包

```bash
# 命令行搜索
nix search nixpkgs#<keyword>

# 或在线搜索：https://search.nixos.org/packages
```

## Home Manager 更新

Home Manager 随 `nixos-rebuild` 自动更新。如需单独应用：

```bash
home-manager switch --flake .#master
```
