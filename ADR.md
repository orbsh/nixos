# Architecture Decision Records

## ADR-001: Overlay 启用策略 — 按域而非按配置值

**日期**: 2026-06-01
**状态**: 已采纳
**上下文**: `libs/nixos-builder.nix` 第 27 行

### 问题

如何决定哪些节点应用 `modules/overlay/` 下的自定义 overlay（如 nushell 0.113.0）？

### 备选方案

| 方案 | 描述 | 缺点 |
|------|------|------|
| A. 按配置值 | 检查 role 模块中的 `programs.nushell.developMode` 或自定义 `nushell.developMode` 属性 | 需要 flake 提前导入 role 模块读取属性；`lib.mkForce` 返回 override 集合而非布尔值；引入模块求值顺序和参数传递复杂性 |
| B. 按文件名 | 检测 imports 是否包含 `workstation-base.nix` | 硬编码文件名，脆弱且不可扩展 |
| **C. 按域** | 通过 `nodeAttrs.domainName == "workstations"` 判断 | 需要新增域时修改判断条件 |

### 决策

采用 **方案 C**：在 `nixos-builder.nix` 中通过 `nodeAttrs.domainName == "workstations"` 决定是否启用 overlay。

```nix
nixpkgs.overlays = lib.optionals (nodeAttrs.domainName or null == "workstations")
  (map (name: import (overlayDir + "/${name}")) overlayFiles);
```

### 理由

1. **扩展合理** — workstations 是开发机，应用全部 overlay 符合直觉。**未来新增的 overlay（如自定义编译器、开发工具等）会自动生效，无需额外配置**。其他域（k8s/server/portable）用 nixpkgs 官方包，避免不必要的下载和构建
2. **改动最小** — 只改 builder 一行，不需要在 flake.nix 中传递额外配置，不需要修改 `builderKeys`
3. **职责清晰** — overlay 是 nixpkgs 打包层面的概念，应在构建器中统一决策。按域判断时：
   - **Builder 层**：决定「哪些机器需要自定义包」（一个域级判断）
   - **Role 层**：只声明「这个角色的功能需求」（如 workstation-base 声明需要开发工具、桌面环境）
   - 两层不互相渗透
   - 反之，如果在 builder 中读取 role 模块的 `programs.nushell.developMode`，role 模块就要知道「我设置这个值会影响 overlay 是否启用」，职责耦合
4. **无间接依赖** — 不需要在 flake 层提前导入 role 模块，避免了 `pkgs` 参数缺失、`lib.mkForce` 类型不匹配等问题

### 后果

- 新增需要 overlay 的域时，需在 builder 中添加对应的域名判断
- 如果将来某个非 workstations 域也需要 overlay，可改为白名单模式：`builtins.elem domainName [ "workstations" "other" ]`

---

## ADR-002: Nushell 版本与 Develop Mode 是两个独立维度

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

---

## ADR-003: 系统配置画像目录命名 — `presets/` 而非 `roles/`

**日期**: 2026-06-01
**状态**: 已采纳

### 问题

`modules/roles/` 目录（workstation-base.nix、server.nix 等）与 K8s 节点的 `role = "combo"`（control/worker/combo）同名但含义不同，容易混淆。

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
