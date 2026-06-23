# ADR-004: 系统配置画像目录命名 — `presets/` 而非 `roles/`

**日期**: 2026-06-01
**状态**: 已采纳

### 问题

`modules/roles/` 目录（workstation.nix、server.nix 等）与 K8s 节点的 `role = "combo"`（control/worker/combo）同名但含义不同，容易混淆。

### 备选方案

| 方案 | 优点 | 缺点 |
|------|------|------|
| `profiles/` | NixOS 生态常见 | 太人格化（profile 暗指"用户画像"），且与 `desktop/presets/` 层级不一致 |
| **`presets/`** | 与 `desktop/presets/`（mini/base/full）命名层级一致；`-sets` 后缀与 `assets` 巧合对称；语义是"预设配置集"，无人格化 | 无 |
| `base/` | 简单 | 与已有 `system/base.nix` 等混淆 |
| `flavors/` | 其他生态常见 | NixOS 中不常用 |

### 决策

`modules/roles/` → `modules/presets/`

**K8s 的 `role` 保持不变** — `role = "combo"` 是 K8s 节点的集群功能属性（control plane / worker），与系统配置画像属于不同维度，无需改名。

### 理由

1. **消除歧义** — `presets/`（系统配置预设）与 `role = "combo"`（K8s 节点功能）不再同名
2. **层级一致** — 与 `desktop/` 下的预设（mini.nix / base.nix / full.nix）概念统一，都是"配置预设集"
3. **命名对称** — `presets` 与 `assets` 共享 `-sets` 后缀，视觉和语义上协调
4. **避免人格化** — `profiles` 暗指"用户画像/角色设定"，`presets` 更中性，只表达"一组预设配置"

### 后果

- 所有 import 路径从 `../../modules/roles/` 改为 `../../modules/presets/`
- README 等文档中的路径引用需要同步更新
