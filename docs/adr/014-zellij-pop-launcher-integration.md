# ADR-014: Zellij + Pop-launcher 集成方案

**日期**: 2026-06-18
**状态**: 已采纳

### 问题

需要一个快速切换 zellij session 的方式，同时支持：
1. 快速查看和切换多个任务上下文
2. 与 pop-launcher 集成，通过 `zz` 触发
3. 自动创建不存在的 session

### 备选方案

| 方案 | 优点 | 缺点 |
|------|------|------|
| **A. 单 session 多 tab** | 切换快（Alt+数字），所有任务集中 | pop-launcher 只能 attach 到一个 session；tab 需要记住编号 |
| **B. 每个任务一个 session** | pop-launcher 可列出所有 session；独立隔离 | session 数量多，需要管理 |
| **C. pueue 任务队列** | 真正的任务队列，支持优先级、依赖 | 没有交互式终端，只能看日志，不适合需要 nushell 补全的场景 |
| **D. tmux + pop-launcher** | tmux 更成熟 | 配置复杂，插件生态不如 zellij |

### 决策

采用 **方案 B：每个任务一个 session**，具体包含以下子决策：

#### 1. 每个任务一个 session

**理由**：
- pop-launcher 集成：`zz` 触发后列出所有 session，快速切换
- 任务隔离：每个任务独立，不会互相干扰
- 资源无压力：detached session 开销极小（空 session 几 MB，运行 nvim 约 50-200 MB）

**资源占用分析**：
- 10 个 detached session 的额外开销 < 50 MB，可以忽略
- Ghostty 窗口保持 1 个（Alt+tab 友好），zellij session 通过 `zz` 快速切换

#### 2. 自动创建 session

**行为**：
- `zz xxx` 时，如果 session 不存在，自动创建
- 使用 `zellij attach --create <name>` 实现

**理由**：
- 减少操作步骤，无需先创建再 attach
- 符合"快速切换"的设计目标

#### 3. 进程退出后 session 行为

**默认行为**：进程退出 → session 自动结束

**理由**：
- 自动清理，不会积累无用 session
- 如果需要持久化，可后续配置 `auto_exit false`

### 实现

#### Pop-launcher 插件

**文件**：`modules/desktop/assets/pop-launcher/zellij/main.py`

**逻辑**：
```python
# 查询 session 列表
sessions = zellij list-sessions --no-formatting

# 用户输入 xxx
if xxx in sessions:
    # attach 到现有 session
    zellij attach xxx
else:
    # 创建新 session
    zellij attach --create xxx
```

**触发词**：`zz`

#### NixOS 集成

- 插件由 NixOS 管理（`xdg.dataFile`）
- 合并到 `cosmic.nix`（与 cwdhist 插件同级）

### 理由

1. **快速切换**：`zz` 触发，1 秒内进入目标 session
2. **交互式**：session 内可用 nushell 补全、输入命令
3. **可视化**：多 session 查看不同任务
4. **资源轻量**：detached session 开销极小

### 后果

- 新增 pop-launcher 插件 `zellij`
- 插件由 NixOS 管理，合并到 `cosmic.nix`
- 用户可通过 `zz` 快速切换 zellij session
- session 不存在时自动创建
