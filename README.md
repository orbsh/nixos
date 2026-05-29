# NixOS 26 Flake Configuration

> 基于 NixOS unstable 的模块化 Flakes 配置，支持 **工作站 (workstation)**、**服务器 (server)**、**虚拟机 (qemu)** 与 **K8s 集群 (k8s-control / k8s-worker)**。

---

## 📁 目录结构

```
nixos/
├── flake.nix                     # Flake 入口，定义主机 + 便携系统构建
├── hosts/
│   ├── workstation/              # COSMIC 桌面工作站
│   ├── server/                   # 无头服务器 (K8s 节点)
│   ├── qemu/                     # QEMU/KVM 虚拟机
│   ├── portable/                 # USB 便携系统盘（通用安装/救援环境）
│   ├── k8s-role.nix              # K8s 角色模板（数据驱动）
├── config/
│   └── nodes.nix               # K8s 集群节点定义
└── modules/
    ├── common/                   # 通用模块（所有主机共享）
    ├── workstation/              # 工作站专用模块
    ├── server/                   # 服务器专用模块
    └── home/                     # Home Manager 用户环境配置
```

---

## 📖 主机文档

| 主机 | 安装指南 | 升级/迁移指南 |
|------|----------|---------------|
| **服务器 (server)** | [docs/server.md](docs/server.md) | [docs/upgrade-guide.md](docs/upgrade-guide.md) |
| **工作站 (workstation)** | [docs/workstation.md](docs/workstation.md) | [docs/upgrade-guide.md](docs/upgrade-guide.md) |
| **虚拟机 (qemu)** | [docs/server.md](docs/server.md)（参考服务器流程） | — |
| **便携系统 (portable)** | [x.nu](x.nu) `portable install` | 本 README → 💾 便携式系统 |
| **K8s 集群** | [docs/server.md](docs/server.md) → K8s 章节 | — |

---

## 🔧 其他文档

- [docs/daily-ops.md](docs/daily-ops.md) — 日常操作（更新、回滚、垃圾回收）
- [docs/temp-envs.md](docs/temp-envs.md) — 临时程序（nix run / nix shell）
- [docs/dev-shells.md](docs/dev-shells.md) — 项目级环境配置（类似 Python venv）
- [docs/iso.md](docs/iso.md) — 构建与使用 Live ISO
- [docs/running-binaries.md](docs/running-binaries.md) — 运行外部二进制文件
- [docs/upgrade-guide.md](docs/upgrade-guide.md) — 升级与迁移总览（含 Arch 原地转换与 NixOS Anywhere）

---

## 📦 预装开发环境

以下工具已随系统安装，开箱即用：

| 语言/运行时 | 包含组件 |
|-------------|----------|
| **Bun** | JS/TS 主运行时 |
| **Rust** | rustup, cargo, sccache, rust-analyzer |
| **Haskell** | GHC, cabal, stack, HLS |
| **Python** | uv + fastapi, uvicorn, pytest, pydantic, polars, ipython 等 |
| **WASM** | wasmtime |
| **C/C++** | gcc, cmake, gnumake, pkg-config |

---

## 💾 便携式系统（portable）

portable 是安装在移动硬盘上的 NixOS，可插到不同机器启动。在本机系统上更新它时，使用 `x.nu` 中的工具：

```nu
# 1. 挂载移动硬盘（自动挂载 btrfs 子卷 + EFI）
use x.nu portable
portable mount-btrfs

# 2. 更新 portable 系统
portable switch

# 可选：指定不同 host 或配置路径
portable switch -h workstation
portable switch -c /path/to/config -h portable

# 可选：进入 chroot 调试
portable enter
```

`switch` 在宿主机上直接调用 `nixos-install --root /mnt --no-root-password`，无需 chroot 即可更新。`enter` 保留用于手动排查场景。

**常见问题**：
- `nix flake update` 报 public key 错误 → [查看故障排除](docs/install-guide.md#q-nix-flake-update-或-nixos-rebuild-报-public-key-错误)

---

## ⚠️ 占位符替换

使用前请修改以下占位符：

| 文件 | 占位符 |
|------|--------|
| `flake.nix` | `user = "master"` → 你的用户名 |
| `flake.nix` | `email = "nash@iffy.me"` → 你的邮箱 |

---

## 📋 本地包与纯评估模式

本配置使用 `lib/local-pkg.nix` 和 `modules/gui/input-method.nix` 引用本地文件（如 `.deb`、`.AppImage`、Rime 五笔数据）。这些文件位于 `/home/${user}/pub/` 或 `/home/${user}/data/` 目录下。

由于 Nix flakes 默认运行在 **纯评估模式 (pure evaluation)** 下，不允许访问任意本地路径，因此重建时需要添加 `--impure` 标志：

```bash
sudo nixos-rebuild switch --flake .#workstation --impure
```

### 替代方案（免 `--impure`）

若需要在 CI/CD 或纯评估环境下构建，可：

1. **将文件移入 flake 树**：将本地包放入配置仓库内（如 `./pkgs/local/`）
2. **使用 `fetchurl`**：从 URL 下载（适用于公开的 `.deb`/`.AppImage`）
3. **使用 `fetchGit`**：从 Git 仓库获取（适用于 Rime 五笔数据等）

### 受影响的模块

| 模块 | 路径 | 用途 |
|------|------|------|
| `lib/local-pkg.nix` | `/home/${user}/pub/Application/Linux/` | Vivaldi、微信等本地包 |
| `modules/home/rime.nix` | `/home/${user}/data/rime-wubi/` | Rime 五笔输入法数据 |
| `modules/home/rime.nix` | `data/rime-lua/rime.lua` | Rime Lua 脚本（内置于 flake 树） |

### Fcitx5 自动启动

NixOS 的 `i18n.inputMethod` 模块会自动创建 XDG autostart 条目，在图形会话启动时加载 fcitx5。

**重要**：每次更新输入法配置后，需要重启 fcitx5 以加载新 addon：

```bash
fcitx5-remote -r   # 或 killall fcitx5 后重新登录
```

如果重启后 fcitx5 未启动，检查是否运行了正确的二进制：
```bash
which fcitx5        # 应指向 /run/current-system/sw/bin/fcitx5
fcitx5 -d           # 手动启动守护进程
```