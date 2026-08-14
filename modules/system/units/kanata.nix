{ pkgs, ... }:
{
  # ── kanata：evdev 层键盘重映射（Rust 实现） ─────────────
  # 作用在内核输入层（keycode），对所有应用生效（含 Blender、游戏、TTY、Wayland 原生）。
  # 与 XKB（keysym 层）不同：XKB 的 ctrl:swapcaps 只对走 keysym 的应用生效，
  # kanata 直接替换物理键码，Blender 等以 keycode 为输入源的软件也认。
  #
  # 键位取舍与理由见 ADR-021: docs/adr/021-keyboard-ctrlcaps-swap.md
  # （ADR-019 的 caps 双模 esc/ctrl 已取消，原因分析见 ADR-021）
  #
  # 设计：
  # - 物理 CapsLock → lctl（Ctrl），纯单键，无 tap-hold、无 esc 双模
  # - 物理左 Ctrl → 点击 caps；按住切到鼠标层（应急鼠标控制，保留）
  # 其余键（shift/alt/右 ctrl）全部还原为普通键：
  # - shift 保留 RIME 单击切换中英文、idea 双击 shift 搜索等原语义
  # - 括号不设快捷方式，直接用物理键 shift+9 / shift+0（程序员对符号区熟练）
  # - esc 用物理键（无名指，手掌不动）或组合键 Ctrl+[，几乎用不上独立 esc
  #
  # CapsLock 上不再做 tap-hold 的原因（见 ADR-021）：tap-hold 把"修饰键
  # 下按时刻"引入到一个可变判定窗口，终端 raw mode 下 Ctrl+字符（单字节
  # 控制符）与 Esc/Alt（0x1b 前缀序列）共用字节通道，快按坍缩成 Esc 后会被
  # zellij 等误判为模式键/Alt 键。Ctrl 必须是"按下即成立"的物理键。
  # （物理左 Ctrl 上的 tap-hold 仅服务于 caps/mouse 层，不参与终端修饰键。）
  services.kanata = {
    enable = true;

    keyboards.default = {
      # devices = [] 自动检测所有键盘设备
      # defcfg 的其余选项走 extraDefCfg（模块自动生成 defcfg 头部，含 linux-dev）
      # tap-hold 相关选项仅服务于物理左 Ctrl 的 caps/鼠标层 tap-hold
      extraDefCfg = ''
        process-unmapped-keys yes
        tap-hold-require-prior-idle 150
      '';

      config = ''
        (defalias
          ;; 物理左 Ctrl：点击 caps，按住切到鼠标层（应急鼠标控制）
          lctl-mod (tap-hold-press 200 200 caps (layer-while-held mouse))
          ;; 鼠标动作：匀加速（10ms 间隔，3000ms 内从 2px 线性爬到 50px）
          ;; 短点按=精确微调，长按=快速扫过，无需额外按键
          mup    (movemouse-accel-up 10 3000 2 50)
          mdown  (movemouse-accel-down 10 3000 2 50)
          mleft  (movemouse-accel-left 10 3000 2 50)
          mright (movemouse-accel-right 10 3000 2 50)
          mlbtn  mltp
          mrbtn  mrtp
          mmbtn  mmtp
          mwhu   (mwheel-up 50 120)
          mwhd   (mwheel-down 50 120))

        (defsrc
          caps lctl i j k l u o m p ;)

        ;; base：物理 CapsLock=Ctrl（纯单键）；物理左 Ctrl 点击 caps，按住鼠标层；其余还原普通键
        (deflayer base
          lctl @lctl-mod i j k l u o m p ;)

        ;; mouse 层：ijkl 品字形移动鼠标（匀加速），u/o/m 三键，p/; 滚轮
        (deflayer mouse
          _ _ @mup @mleft @mdown @mright @mlbtn @mrbtn @mmbtn @mwhu @mwhd)
      '';
    };
  };

  # ── 蓝牙键盘重连自动重启 kanata ─────────────────────────
  # kanata 自带 inotify watch /dev/input,但蓝牙键盘断开时 ungrab 失败
  # (No such device),内部状态卡住,重连后不再重新 grab 导致 remap 失效(实测)。
  # udev 是内核级事件,蓝牙重连必然触发 ACTION=="add",此时重启 kanata 必重新 grab。
  # 匹配 ENV{ID_BUS}=bluetooth + ENV{ID_INPUT_KEYBOARD},覆盖所有蓝牙键盘,不绑定具体型号。
  # 注意:ID_BUS/ID_INPUT_KEYBOARD 是属性,须用 ENV{} 前缀匹配,裸键名会被 udevadm verify 拒绝。
  services.udev.extraRules = ''
    ACTION=="add", KERNEL=="event*", ENV{ID_BUS}=="bluetooth", ENV{ID_INPUT_KEYBOARD}=="1", \
      RUN+="${pkgs.systemd}/bin/systemctl restart kanata-default"
  '';
}
