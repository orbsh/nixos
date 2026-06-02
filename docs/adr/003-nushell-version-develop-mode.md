# ADR-003: Nushell 版本与 Develop Mode 是两个独立维度

**日期**: 2026-06-01
**状态**: 已采纳

### 问题

nushell 的「版本」（overlay 控制）和「配置部署方式」（developMode 控制）容易混淆，需明确各自职责。

### 概念区分

| 维度 | Overlay（版本） | Develop Mode（配置部署） |
|------|------|------|
| **控制什么** | nushell 二进制版本（0.113.0 vs 0.112.2） | nushell **配置文件**从哪来 |
| **在哪设置** | `modules/overlay/nushell.nix` | `programs.nushell.developMode` in role 模块 |
| **生效范围** | 系统级 `pkgs.nushell` | Home Manager 用户配置 |
| **设置者** | 域（flake builder 决定是否启用） | 角色模块（声明配置部署方式） |

### Overlay 方式的优缺点

| 优点 | 缺点 |
|------|------|
| 不依赖 nixpkgs 更新周期，可立即用最新版 | 需手动维护 `version`、`url`、`sha256` |
| 用官方预编译 musl 二进制，构建快 | 绕过 nixpkgs 审查，可能有兼容性风险 |
| 非 workstations 节点不下载，不浪费带宽 | 更新版本需改 overlay 文件 |

### Develop Mode 两种模式对比

| | `developMode = true` | `developMode = false` |
|---|---|---|
| **配置来源** | symlink 到 `~/Configuration/nushell` 本地 git 仓库 | 从 flake input 的 store 路径复制 |
| **修改后** | 编辑文件即刻生效（nu 重启后） | 需 rebuild 才能生效 |
| **适用场景** | 开发/调试 nushell 配置 | 生产/稳定使用 |
| **ISO 部署** | 不能用（symlink 导致 xorriso 报错） | 可用（store copy 注入） |

### 组合策略

两者独立，可任意组合：

| 版本来源 | Develop Mode | 场景 |
|------|------|------|
| Overlay（最新版） | `true` | **workstations**：最新版 + 本地配置实时编辑 |
| 官方 nixpkgs | `false` | **k8s/server/portable/ISO**：稳定版本 + 固化配置 |
| Overlay | `false` | 测试新版 nushell 但用固化配置 |
| 官方 nixpkgs | `true` | 用稳定版但调试本地配置 |

### 当前配置

- **workstations** → overlay + developMode=true（开发机组合）
- **k8s/server/portable/ISO** → 官方 + developMode=false（生产组合）
