# NixOS 26 Flake Configuration

> 基于 NixOS unstable 的模块化 Flakes 配置，支持 **工作站 (workstation)**、**服务器 (server)**、**虚拟机 (vbox)** 与 **K8s 集群 (k8s-control / k8s-worker)**。

---

## 📁 目录结构

```
nixos/
├── flake.nix                     # Flake 入口，定义主机 + ISO 构建
├── hosts/
│   ├── workstation/              # COSMIC 桌面工作站
│   ├── server/                   # 无头服务器 (默认 Nomad)
│   ├── vbox/                     # VirtualBox 虚拟机
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
| **K8s 集群** | [docs/server.md](docs/server.md) → K8s 章节 | — |

---

## 🔧 其他文档

- [docs/daily-ops.md](docs/daily-ops.md) — 日常操作（更新、回滚、垃圾回收）
- [docs/temp-envs.md](docs/temp-envs.md) — 临时环境与 devShells
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

## ⚠️ 占位符替换

使用前请修改以下占位符：

| 文件 | 占位符 |