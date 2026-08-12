# ADR-020: Nix GC 统一策略（按代 / 按时间 / 空间三维）

**日期**: 2026-08-12
**状态**: 已采纳
**涉及**: `modules/system/units/gc.nix`, `modules/system/units/nix.nix`, `profiles/server.nix`, `profiles/workstation.nix`

### 问题

Nix store 的垃圾回收策略需要按节点角色差异化，且存在两个实际痛点：

1. **`nix-collect-garbage` 无法按「代」清理** — 它只支持 `--delete-older` / `--delete-older-than` / `--max-freed`，**不支持 `--keep-generations`**（Nix 2.34.8 实测）。原配置里写的 `--keep-generations 20` 是无效参数，会导致 GC 直接报错。
2. **服务器与工作站更新频率差异巨大**：
   - **服务器**可能几个月才更新一次，按时间（`--delete-older-than`）清理没有意义——generation 都太新永远不会触发，而更新一次后旧代又全被清掉
   - **工作站**频繁 rebuild，nixos-unstable 滚动更新，旧版本堆积快，需要及时释放磁盘

需要一套能按节点角色灵活组合「按代 / 按时间 / 空间」的 GC 策略。

### 决策

新增独立模块 `modules/system/units/gc.nix`，提供 `nix.gc` 命名空间下的四个正交选项，由同一 systemd 服务执行：

| 选项 | 作用 | 默认 |
|------|------|------|
| `nix.gc.keepGenerations` | 保留最近 N 代（`nix-env --delete-generations +N`） | `null`（不按代） |
| `nix.gc.deleteOlderThan` | 删除超过指定时间的 generation（如 `"14d"`） | `"30d"` |
| `nix.gc.minFree` | 可用空间低于该字节数时 daemon 自动清理 | 50G |
| `nix.gc.maxFree` | 清理到可用该字节数为止 | 100G |

策略按节点角色分级：

| 节点 | keepGenerations | deleteOlderThan | 说明 |
|------|-----------------|-----------------|------|
| **server / k8s** | `50` | `null` | 更新慢，只按代，保留完整回滚能力 |
| **workstation** | `10` | `14d` | 更新快，按代 + 按时间双重清理 |
| **portable / qemu**（默认） | `null` | `30d` | 只按时间 |

### 实现

- `nix.gc` 选项在 `gc.nix` 中通过 `options` 声明，`config` 内用 `lib.mkIf` 条件激活（任一策略启用时才生成服务）
- 空间阈值 `min-free`/`max-free` 注入 `nix.settings`（daemon 层），在**磁盘满时每次构建/下载前自动触发**，优先保业务——这是与应用软件量无关的兜底，不随按代/按时间策略走
- `nix-gc-policy` systemd 服务（每周）执行 `nix-env --delete-generations`（按代 + 按时间）后再 `nix-collect-garbage` 清理不可达路径，覆盖 `/nix/var/nix/profiles/system` 及所有 per-user/home-manager profile
- 启用时关闭内置 `nix.gc.automatic`，避免与 `nix-collect-garbage` 定时器重复
- `profiles/server.nix` / `profiles/workstation.nix` 用 `lib.mkForce` 覆盖 `nix.gc` 默认值

### 理由

1. **按代是刚需且内置不支持** — `nix.gc.options` 只接受 `nix-collect-garbage` 参数，无法按代；必须用 `nix-env --delete-generations +N`，故需要自定义 systemd 服务
2. **正交参数优于单一模式** — 拆成 `keepGenerations` / `deleteOlderThan` / `minFree` / `maxFree` 四个独立维度，各节点自由组合，无需为每种场景硬编码新配置
3. **空间参数与策略同处配置** — 空间阈值是 GC 策略的一部分，统一放在 `nix.gc` 命名空间，而非散落在 `nix.settings`，语义内聚、可发现性好
4. **空间兜底不依赖应用软件量** — 只清不可达路径，不删 generation，避免「live closure 超上限导致清不到目标」的死锁；磁盘满时仍有 daemon 层兜底保业务

### 后果

- `nix.nix` 仅保留 Nix 自身配置（settings / direnv / nix-index / 生态工具），GC 策略独立到 `gc.nix`
- 服务器更新慢也能保留最多 50 代回滚点；工作站及时释放磁盘
- 空间阈值（50G/100G）与按代/按时间策略解耦，全局生效
- 需要 `nixos-rebuild switch` 后，`nix-gc-policy` 服务及新策略才生效
