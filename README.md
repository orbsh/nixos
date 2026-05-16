# NixOS 26 Flake Configuration

> 基于 NixOS unstable 的模块化 Flakes 配置，支持 **工作站 (workstation)**、**服务器 (server)**、**虚拟机 (vbox)** 与 **K8s 集群 (k8s-control / k8s-worker)**。

---

## 📁 目录结构

```
nixos/
├── flake.nix                     # Flake 入口，定义主机 + 便携系统构建
├── hosts/
│   ├── workstation/              # COSMIC 桌面工作站
│   ├── server/                   # 无头服务器 (K8s 节点)
│   ├── vbox/                     # VirtualBox 虚拟机
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
| **虚拟机 (vbox)** | [docs/server.md](docs/server.md)（参考服务器流程） | — |
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

`switch` 在宿主机上直接调用 `nixos-rebuild --root /mnt`，无需 chroot 即可更新。`enter` 保留用于手动排查场景。

---

## ⚠️ 占位符替换

使用前请修改以下占位符：

| 文件 | 占位符 |