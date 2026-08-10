# ADR-019: 键盘键位重映射设计

**日期**: 2026-08-10
**状态**: 已采纳
**涉及**: `modules/system/units/kanata.nix`, `modules/system/units/sys.nix`, `modules/desktop/units/rime.nix`

### 问题

键盘上有几个"位置不合理"的键,导致日常使用效率受损:

1. **Ctrl 位置不理想** — 物理左 Ctrl 在键盘最左下角,需要手掌大幅移动才能按到
2. **esc 位置太远** — 对 vim/终端用户是知名痛点,右上角离主键区太远
3. **括号输入** — 需要按 `shift+9` / `shift+0`(两个键)

需要一个统一的键位重映射方案,同时不能破坏依赖单键原始语义的应用功能。

### 决策

**用 kanata 在 evdev 层做键位重映射**,只保留两条映射:

| 物理键 | 行为 |
|--------|------|
| CapsLock | 点击输出 esc,按住输出 Ctrl(双模) |
| 物理左 Ctrl | 改回 caps(大小写锁定) |

其余键(shift/alt/右 Ctrl)**全部还原为普通键**,不做任何双模映射。

映射集中在 `modules/system/units/kanata.nix`:

```
caps-mod (tap-hold-press 200 200 esc lctl)   # CapsLock: 点击 esc / 按住 Ctrl
lctl-mod caps                                 # 物理左 Ctrl → caps
```

同时从 `sys.nix` 移除 XKB 的 `options = "ctrl:swapcaps"`,避免与 kanata 双层冲突。

### 关键取舍

#### 1. 为什么用 kanata(evdev 层)而非 XKB

XKB 的 `ctrl:swapcaps` 作用在 keysym(逻辑键)层,只对走 keysym 的常规应用生效。**Blender 等以 keycode(物理键码)为输入源的软件不认 XKB 映射**——这正是用户最初发现问题(Blender 中 caps↔ctrl 不生效)的根因。

kanata 作用在 evdev(内核输入层,keycode),先于 TTY、X11、Wayland、Blender,对所有应用一视同仁,TTS 控制台也生效。

#### 2. 为什么 shift 完全还原,不做双模

最初尝试过把括号绑定到 shift 双模(点击 shift 输出 `)`,按住保持 shift),但**占满 shift 会连锁破坏依赖 shift 原始语义的功能**:

- RIME 输入法单击 shift 切换中英文
- idea 双击 shift 搜索
- 大写输入

这些功能靠"shift 键本身被点击"的键事件触发,一旦 shift 的双模把 tap 重定向成输出字符,应用层就永远收不到 shift 被点击的事件。**牺牲点按副作用的键,会破坏所有依赖该键原生语义的应用。**

#### 3. 为什么括号不设快捷方式

尝试过把括号挪到 Alt 双模(左 Alt 点击 `(`,右 Alt 点击 `)`),但:

- 右 Alt 位置难按
- Alt 键位容易受空格键长度影响
- `()` 输入本身已习惯,用物理 `shift+9` / `shift+0` 即可

**程序员对符号区(shift+数字)的熟练度和主键区区别不大**,不需要额外快捷键。占满 Alt 还会破坏 Alt+Tab 等组合键,得不偿失。

#### 4. 权衡:tap-hold 的延迟

caps 双模用 `tap-hold-press`:
- 按住 CapsLock 再按另一键 → 立即判定为 hold(组合键零延迟)
- 点按 CapsLock → 输出 esc

`tap-hold-require-prior-idle 150` 让打字流中的点按立即判 tap。组合键零延迟,CJK 等场景无感。

### 理由

1. **解决两个位置不合理** — CapsLock 一个键位同时解决 esc 太远和 Ctrl 位置不佳
2. **兼容 vim 习惯** — 点按 CapsLock 出 esc;CapsLock(当 Ctrl)+ `[` 即 `Ctrl+[`(vim 中等效 esc),两条路都保留
3. **不破坏应用语义** — 只占满"点按副作用最小"的键位(CapsLock),保留 shift/alt 原生功能
4. **Blender 等全应用生效** — evdev 层绕开 XKB 的 keysym 局限

### 后果

- 物理 CapsLock 不再是大写锁定(改由物理左 Ctrl 充当 caps)
- 物理左 Ctrl 失去 Ctrl 功能(改由 CapsLock 按住充当)
- 需要 `process-unmapped-keys yes` 让未映射键(字母/数字/shift/alt 等)照常 pass-through
- kanata 全局启用(所有 host),SSH 输入不受影响(evdev 层,不碰网络输入)