# ADR-020: Nix GC 策略（按代）

**日期**: 2026-08-12
**修订**: 2026-09-21 —— 收敛为单一「按代」维度（去掉按时间、按空间两条）
**状态**: 已采纳
**涉及**: `modules/system/units/gc.nix`, `profiles/server.nix`, `profiles/workstation.nix`

### 问题

Nix store 的垃圾回收需要按节点角色差异化，且存在两个实际痛点：

1. **`nix-collect-garbage` 无法按「代」清理** — 它只支持 `--delete-older` / `--delete-older-than` / `--max-freed`，**不支持 `--keep-generations`**（Nix 2.34.8 实测）。原配置里写的 `--keep-generations 20` 是无效参数，会导致 GC 直接报错。
2. **服务器与工作站更新频率差异巨大**：
   - **服务器**可能几个月才更新一次，按时间（`--delete-older-than`）清理没有意义——generation 都太新永远不会触发，而更新一次后旧代又全被清掉
   - **工作站**频繁 rebuild，nixos-unstable 滚动更新，旧版本堆积快，需要及时释放磁盘

需要一条与更新频率无关、可预测的收敛规则：给定「保留最近 N 代」，store 大小就有确定的上界。

### 决策

独立模块 `modules/system/units/gc.nix` 提供 `nix.gc.keepGenerations` 一个选项，由 `nix-gc-policy` systemd 服务执行：

| 选项 | 作用 | 默认 |
|------|------|------|
| `nix.gc.keepGenerations` | 保留最近 N 代（`nix-env --delete-generations +N`） | `10`（与 systemd-boot `configurationLimit` 对齐）；`null` = 不清理 generation |

策略按节点角色分级：

| 节点 | keepGenerations | 说明 |
|------|-----------------|------|
| **server / k8s** | `20`（`lib.mkForce`） | 更新慢，留更多回滚点 |
| **workstation / portable / qemu** | `10`（模块默认，不重复声明） | 更新快，10 代足够回滚 |

### 实现

- `nix.gc` 选项在 `gc.nix` 中声明，`config` 内用 `lib.mkIf` 条件激活（`keepGenerations != null` 时才生成服务，也让单个 host 能关掉策略）
- `nix-gc-policy` 服务每周执行：对 `/nix/var/nix/profiles/system` 及所有 per-user/home-manager profile 跑 `nix-env --profile <p> --delete-generations +N`，再跑**无参数**的 `nix-collect-garbage` 回收不可达路径
- 启用时关闭上游 `nix.gc.automatic`，避免与内置定时器重复清理
- `timerConfig.Persistent = true` + `RandomizedDelaySec = "1h"`：关闭期跨过调度点时，开机补跑一次（`startAt` 简写生成的 timer 只带 `OnCalendar`，故单独覆盖）。长期开机的机器 timer 一直处于 active，不存在 inactive 窗口，此设置对其无影响；它服务的是会关机/挂起的节点。systemd 只在开机时补跑一次，不按错过次数重放。随机延迟对每次触发都生效（含周一 00:00 的正常触发与开机补跑），把一次全店扫描的 GC 摊开在触发后的 1 小时内，避免与开机 I/O 抢资源。
- 不再注入 `nix.settings.min-free` / `max-free`

### 理由

1. **按代是刚需且内置不支持** — `nix.gc.options` 只接受 `nix-collect-garbage` 的参数，无法按代；按代只能走 `nix-env --delete-generations +N`，因此必须有自定义服务。
2. **回滚窗口用数量定义，不用时间定义** — `nix-env --delete-generations` 一次只接受一种规则，`+N` 与 `Nd` 混用直接报 `invalid generation number`（Nix 2.34.8）。若选时间规则，删除量就成了时间的函数，会突破「至少保留 N 代」的下限；而 `+N` 是保留量的下限，语义与「回滚窗口」直接对应。因此时间维度被上游能力排除。
3. **空间阈值与代数正交，且解决不了代数问题** — `min-free` / `max-free` 注入的是 daemon 层 GC：磁盘低于 `min-free` 时清到 `max-free` 可用**或再无不可达路径**为止（`nix.conf(5)`：*until max-free bytes are available or there is no more garbage*）。generation 是 GC root，不是 garbage，这条路径**一个代也删不掉**。它既不能替代按代策略（代数不会收敛），也不能在空间不足时把代数降到 N 以下（`live closure` 就是 store 全部内容时它清无可清）。既然它管不到回滚窗口，就不该放在 GC 策略命名空间里让人误以为它是第二个维度。
4. **单一维度胜过多维堆叠** — 四个正交选项的初衷是「各节点自由组合」，但按时间被上游限制否掉、按空间与代数无关，实际剩下的自由度只有 N 这一个数。留下 `null` 只用于关闭策略，不再保留无人使用的维度。
5. **去掉空间兜底的代价可量化** — store 的大小由被保留的 N 代 closure 决定（本机收敛到 10 代后 `/nix/store` 约 78G，根分区可用 600G 量级）。空间兜底只在可用低于 50G 时才会触发，与「按什么规则清理」无关；去掉后磁盘满的表现是构建直接 `ENOSPC`，恢复手段是手动 `nix-collect-garbage` 或等每周 tick。

### 后果

- 代数上限是硬的：每周收敛到最近 N 代，空间压力不会让代数降破 N（`min-free` 本来就做不到这件事）。
- tick 之间代数会堆积，最多堆一周；正常收敛点是周一 00:00（`OnCalendar=weekly`），关机/挂起跨过该点则在下次开机时补跑一次。补跑是一次全店扫描的 GC（本机实测同量级工作约 6 分钟 wall、2.5 分钟 CPU、2 GB 读 / 5.6 GB 写），发生在开机 I/O 期间。
- 磁盘满时不再有 daemon 层自动回收，构建会以 `ENOSPC` 失败——这是明确接受的取舍，因为分区余量与 store 规模差一个数量级。
- 需要 `nixos-rebuild switch` 后 `nix-gc-policy` 服务与去空间兜底的 `nix.settings` 才生效。