# ADR-021: 键盘键位收敛为纯交换（Ctrl↔Caps，取消 esc 双模）

**日期**: 2026-08-14
**状态**: 已采纳
**涉及**: `modules/system/units/kanata.nix`
**取代**: ADR-019 中「caps 双模 esc/ctrl」的设计决策

### 问题

ADR-019 把 CapsLock 设计成 tap-hold 双模键（点击=esc、按住=Ctrl），并顺带赋予物理左 Ctrl「点按=caps、按住=应急鼠标层」的双模。实践发现两个问题：

1. **esc 双模几乎用不上** — 用户早已习惯用无名指按物理 Esc：手掌不用移动，且「手型变化」本身就是模式切换的明确信号。需要快速触发的场景（vim 模式切换、zellij 退出子模式）直接用组合键 `Ctrl+[` 即可，比 tap-hold 更短、更确定。
2. **Ctrl/Esc 同键在 zellij 里出现兼容问题** — 实测发现 zellij 的 Ctrl 系快捷键快速敲击时经常失效（详见下文字节通道分析），双模键把「Ctrl 组合」的快节奏和 tap-hold 的判定窗口绑在一起，违背了终端输入模型的物理假设。

### 决策

收敛为**最简的一次性交换**，两个键直接对调，无任何 tap-hold、无 esc 输出：

| 物理键 | 行为 |
|--------|------|
| CapsLock | lctl（Ctrl） |
| 物理左 Ctrl | caps |

映射集中在 `modules/system/units/kanata.nix`：

```
(defsrc
  caps lctl)

(deflayer base
  lctl caps)
```

具体调整：

- **移除** `caps-mod (tap-hold-press 200 200 esc lctl)` — 不再在 CapsLock 上输出 esc
- **保留** 物理左 Ctrl 的 tap-hold（`lctl-mod`：点按=caps、按住=鼠标层）与鼠标层 `mouse`（ijkl 移动、u/o/m 三键、p/; 滚轮）——鼠标层是该键的应急功能，与终端输入无关，不受本次兼容性决策影响
- **保留** `extraDefCfg` 中的 `tap-hold-require-prior-idle 150` 与 `process-unmapped-keys yes` — 纯交换本身虽不需要判定窗口，但**物理左 Ctrl 的 caps/鼠标层 tap-hold（`lctl-mod`）仍依赖**它们；保留亦为日后添加 tap-hold 键留余地，无需改配置
- **保留** evdev 层交换（不改 XKB `/sys.nix`），Blender/游戏/TTY/Wayland 原生等 keycode 输入源照常生效

### 关键取舍

#### 1. 为什么放弃 esc 双模

- **习惯成本低**：无名指按物理 Esc 不需移动手掌，手指的伸缩本身就是可感知的模式信号，误触成本比平替键更低
- **有现成的确定性替代**：vim/终端系的 esc 语义可用 `Ctrl+[`（0x1b，与 esc 字节完全相同）一键达成；要的是「快」，不是「近」
- **双模是负资产**：一个键位承载两种语义，任何边界时序都产生歧义，而 esc 的热点场景（输入法、vim、zellij 模式退出）恰好在边界时序上

#### 2. 为什么保留物理左 Ctrl 的鼠标层

物理左 Ctrl 承担「点按 caps、按住鼠标层」的双模，这个 tap-hold **只碰非终端用途的左手组合**（caps 点按、鼠标层应急），不构成终端的 Ctrl 修饰键（Ctrl 已由 CapsLock 单键承担），因此不触发上文③所述的 Esc/Ctrl 字节歧义。顺带这让左 Ctrl 键位仍有「应急鼠标控制」的附加值。

### 分析：为什么 Ctrl/Esc 同键在 zellij 里 Ctrl 不起作用

这是本次放弃双模的直接技术原因。三层机制叠加：

#### ① 终端 raw mode 是单字节通道，Esc 与 Ctrl 分属两种编码

终端（xterm 类）在 raw/一元模式下把按键编码成字节流：

| 按键 | 字节 |
|------|------|
| `Ctrl+字母` | `0x01`–`0x1a`（Ctrl+p=`0x10`）|
| `Esc` | `0x1b` 单字节 |
| `Alt+字母` / `Esc+字母` | `0x1b` + 字母字节（两字节）|

应用（shell / zellij / nvim）靠字节本身区分按键。Ctrl 键必须**物理处于按下状态**才能在键入字母时合成出 `0x01-0x1a`；这和 tap-hold「Ctrl 是否成立由判定窗口决定」根本冲突。

#### ② tap-hold 判定窗口把「快敲 Ctrl」推入灰色地带

`tap-hold-press` + `tap-hold-require-prior-idle 150` 的实际行为：

- 打字流（距上个键 <150ms）手指落下 → **立即判 tap**，输出 esc
- 停顿后孤立点按 → 进入 wait 状态，最多等 200ms 判 hold

终端快捷键最常见的使用节奏是**「打字过程中/刚打完一句话，立刻 Ctrl+字母 保存/移动」**——恰好踩中优先判 tap 的那条分支。于是组合键的首字节从 Ctrl 变成了 0x1b（Esc），后面的字母独立送出，Ctrl 语义丢失。

`process-unmapped-keys yes` 能消掉「字母先于修饰判定到达」的那一小段延迟，但消不掉 prior-idle 的**主动歧义**：系统*故意*在打字流中优先 tap。这是 tap-hold 的物理边界，QMK/keyd 也无法消除。

#### ③ Esc 前缀与 Alt 达到时序歧义，zellij 被放大

一旦 tap 误发 0x1b，紧接着的字母会被终端在 **escape timeout**（几 ms~几十 ms）内合成为 `Alt+字母` 序列，或原样作为两字节发给应用。对依赖 Escape 序列解码的程序（zellij）后果放大——本仓库 zellij 配置（`keybinds clear-defaults=true`）的绑定几乎全是 `Ctrl+Alt+`/`Alt+Shift+` 形式，即 0x1b 前缀序列：

- 用户以为按了 `Ctrl+Alt+s`，实际字节流是「误判的 0x1b」+「Ctrl+s」→ 极可能被解释成 `Alt+Ctrl+s` 或其他未绑定条目
- pane 内应用（nvim 的 `Ctrl+s` 等）→ 字节流变成 0x1b 开头的序列，被 zellij/终端歧义当成 Alt 行为或 unknown
- zellij 自己的 `Esc` 绑定（退出 tab/pane/resize/search 等子模式）也会被「0x1b+字母」的合并污染——0x1b 前缀是时序敏感解码，一旦与相邻字符合流，整段按键序列错位

**结论**：修饰键（Ctrl）必须是一个物理上「无歧义按下」的键。tap-hold 提供的 150–200ms 判定窗口在终端场景就是「Ctrl 是否成立」的不确定期，任何依赖即时组合的快捷键（zellij、nvim、shell）都会踩中。纯交换才是与终端字节协议相容的解。

### 理由

1. **zellij 兼容性** — Ctrl 恢复「按下即成立」，组合键时序完全由手指控制，不再有软件判定窗口
2. **esc 双模无收益** — 习惯已成熟，`Ctrl+[` 覆盖热点，双模的歧义成本大于收益
3. **最小化所有应用负担** — 纯交换对任何应用都是「两张键贴纸互换」，无 tap 误触、无 layer 残留状态、无 TTY/崩溃后键位残留问题

### 后果

- 物理 CapsLock = Ctrl，物理左 Ctrl = CapsLock，无其它行为
- esc 输出由物理 Esc 键与 `Ctrl+[` 承担
- 物理左 Ctrl 的应急鼠标层（ijkl 鼠标）保留（tap caps / hold 鼠标层）
- ADR-019 中的 evdev vs XKB 取舍、shift/括号还原决策**仍然有效**，仅「caps 双模」部分被本 ADR 取代
