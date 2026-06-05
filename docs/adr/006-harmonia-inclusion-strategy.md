# ADR-006: Harmonia 二进制缓存引入策略

**日期**: 2026-06-05
**状态**: 已采纳

### 问题

Harmonia 是轻量级 Nix binary cache 服务，需要在多台主机上运行。不同主机类型的引入需求不同：
- Server 和 K8s 节点：所有节点都需要运行 harmonia 提供缓存服务
- Workstation：只有部分节点需要（如 orbit 作为开发主节点）
- Portable：维护用途，按需单独启用
- QEMU：测试环境，不需要

### 备选方案

| 方案 | 优点 | 缺点 |
|------|------|------|
| 全部加到 preset | 配置统一 | Workstation 会强制所有节点启用，不符合选择性需求 |
| 全部节点单独导入 | 灵活 | 重复代码多，维护成本高 |
| **分层引入** | 兼顾统一与灵活 | 需要理解引入策略 |

### 决策

采用分层引入策略：

1. **Server preset（全加）**
   - `modules/presets/server.nix` 导入 `../flake-srv/harmonia.nix`
   - 自动覆盖：server 主机 + 所有 K8s 节点（通过 `k8s-libs.nix:81`）

2. **Workstation（全加）**
   - `modules/presets/workstation-base.nix` 导入 `../flake-srv/harmonia.nix` 和 `../podman/full.nix`
   - 自动覆盖所有 workstation 节点（orbit / team-alice / team-bob）

3. **Portable（单独加）**
   - 节点单独导入 `../../modules/flake-srv/harmonia.nix`
   - 维护用途，按需启用

4. **QEMU（不加）**
   - 测试环境，无需缓存服务

### 理由

1. **符合实际需求** — Server/K8s 集群需要统一提供缓存；Workstation 只有主节点需要
2. **减少重复** — Server preset 统一处理，避免每个 K8s 节点重复导入
3. **保持灵活** — Workstation 和 Portable 可按需控制
4. **资源优化** — QEMU 等不需要缓存的环境不占用资源

### 后果

| 主机/集群 | Harmonia | 来源 |
|-----------|----------|------|
| workstations (orbit) | ✅ | `presets/workstation-base.nix` |
| workstations (team-*) | ✅ | `presets/workstation-base.nix` |
| server | ✅ | `presets/server.nix` |
| portable | ✅ | 节点直接导入 |
| k8s-dev/large/small/nscc | ✅ | `k8s-libs.nix` → `server.nix` |
| qemu | ❌ | 不需要 |

- 新增 K8s 集群自动获得 harmonia（通过 server preset）
- 新增 Workstation 节点自动获得 harmonia（通过 workstation-base preset）
- Portable 节点需手动导入
