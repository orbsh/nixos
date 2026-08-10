{ lib, ... }:
{
  # ── kanata：evdev 层键盘重映射（Rust 实现） ─────────────
  # 作用在内核输入层（keycode），对所有应用生效（含 Blender、游戏、TTY、Wayland 原生）。
  # 与 XKB（keysym 层）不同：XKB 的 ctrl:swapcaps 只对走 keysym 的应用生效，
  # kanata 直接替换物理键码，Blender 等以 keycode 为输入源的软件也认。
  #
  # 键位取舍与理由见 ADR-019: docs/adr/019-keyboard-keymap-design.md
  #
  # 设计（用户为 QMK 用户，kanata 的 tap-hold 对应 QMK 的 tap-hold）：
  # 1. caps 双模（物理 CapsLock）：点击输出 esc，按住作 Ctrl。
  # 2. 物理左 ctrl → caps（改回大小写锁定键）。
  #    其余键（shift/alt/右 ctrl）全部还原为普通键：
  #    - shift 保留 RIME 单击切换中英文、idea 双击 shift 搜索等原语义
  #    - 括号不设快捷方式，直接用物理键 shift+9 / shift+0（程序员对符号区熟练）
  #
  # 延迟控制（对应 QMK 的 HOLD_ON_OTHER_KEY_PRESS + require-prior-idle）：
  # - tap-hold-press：按住 tap-hold 键时再按下另一键 → 立即判 hold（组合键零延迟）
  # - tap-hold-require-prior-idle 150：打字中（距上个键 <150ms）按下 tap-hold 键
  #   → 立即判 tap（打字流中的符号输出零延迟）
  # - 停顿后孤立点按（如句首）仍走 wait 状态 → 保留一段判定窗口，这是 tap-hold
  #   的物理边界，任何方案（含 QMK/keyd）都无法消除。
  #
  # process-unmapped-keys yes：未被 defsrc 列出的键（字母/数字/功能键等）照常
  # pass-through，且让 tap-hold 的提前判定能看到它们（消除组合键延迟）。
  services.kanata = {
    enable = true;

    keyboards.default = {
      # devices = [] 自动检测所有键盘设备
      # defcfg 的其余选项走 extraDefCfg（模块自动生成 defcfg 头部，含 linux-dev）
      extraDefCfg = ''
        process-unmapped-keys yes
        tap-hold-require-prior-idle 150
      '';

      config = ''
        (defalias
          ;; caps（物理 CapsLock）：点击 esc，按住左 ctrl
          caps-mod (tap-hold-press 200 200 esc lctl)
          ;; 物理左 ctrl → caps（改回大小写锁定键）
          lctl-mod caps)

        (defsrc
          caps lctl)

        (deflayer base
          @caps-mod @lctl-mod)
      '';
    };
  };
}