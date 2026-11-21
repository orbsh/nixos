# herdr 终端复用（独立单元，引入即开启）
{ pkgs, lib, ... }: {
  home.packages = with pkgs; [
    herdr
  ];

  # ── herdr 配置 ────────────────────────────────────────────────
  xdg.configFile."herdr/config.toml".text = ''
    # 关闭首次启动的 onboarding 设置弹窗（config 是只读 symlink，界面里保存不了）
    onboarding = false

    [theme]
    name = "gruvbox-light"

    [keys]
    # 前缀键：Alt+s（保留作备份，高频动作走免 prefix 直接 chord）
    prefix = "alt+s"

    # Zellij 风格：高频动作免 prefix，ctrl+alt+单键直接触发
    goto = ["prefix+o", "ctrl+alt+o"]              # workspace picker（win+a → walker 菜单也有一份）
    focus_pane_left = ["prefix+h", "ctrl+alt+h"]
    focus_pane_down = ["prefix+j", "ctrl+alt+j"]
    focus_pane_up = ["prefix+k", "ctrl+alt+k"]
    focus_pane_right = ["prefix+l", "ctrl+alt+l"]
    split_vertical = ["prefix+0", "ctrl+alt+0"]
    split_horizontal = ["prefix+minus", "ctrl+alt+minus"]
    new_tab = ["prefix+t", "ctrl+alt+t"]
    next_tab = ["prefix+n", "ctrl+alt+n"]
    previous_tab = ["prefix+p", "ctrl+alt+p"]
    close_pane = ["prefix+c", "ctrl+alt+c"]
    zoom = ["prefix+z", "ctrl+alt+z"]
    edit_scrollback = ["prefix+e", "ctrl+alt+e"]
    copy_mode = ["prefix+[", "ctrl+alt+["]

    [terminal]
    # 新窗口/面板默认打开 nushell
    default_shell = "nu"

    # 新面板继承当前激活面板的 cwd（agent 在项目里改文件，开 panel 即在项目里 git diff）
    new_cwd = "follow"

    [ui]
    # tmux 风格：无独立边框和外框；pane 间用空行缝隙分隔（共享边框线太占行）
    pane_borders = true
    pane_outer_borders = false
    pane_gaps = false

    # 鼠标：拖拽调分屏边界 + 滚轮滚动；pane 内应用请求鼠标时仍归应用
    mouse_capture = true

    # agent 状态用静态图标（非色点）：blocked/working/done/idle 各异
    status_indicators = "symbols"

    # workspace 只有一个标签页时隐藏顶栏
    hide_tab_bar_when_single_tab = true

    # agent 完成时直发桌面通知（Noctalia 弹出；回跳靠 win+space 菜单）
    [ui.toast]
    delivery = "system"

    # 状态提示音（内置音：完成 / 需要审批各一）
    [ui.sound]
    enabled = true
  '';

  # ── hermes agent 状态检测覆盖 ─────────────────────────────────
  # 上游 manifest（hermes 2026.07.24.1）只认 OSC 标题 ⏳/✓/⚠ 和 "ctrl+c to interrupt"；
  # 当前 Hermes 0.23 两样都不发（无窗口标题，忙时输入框提示是 locales/en.yaml 的
  # composer.placeholder_busy_*），于是状态永远落到 idle fallback。这里补 working 规则。
  # 本地覆盖优先于 remote；改完 `herdr server reload-agent-manifests` 热生效。
  xdg.configFile."herdr/agent-detection/hermes.toml".text = ''
    id = "hermes"
    version = "2026.11.20.1"
    min_engine_version = 2
    updated_at = "2026-11-20T08:30:00Z"
    aliases = ["hermes-agent"]

    [[rules]]
    id = "osc_title_blocked"
    state = "blocked"
    priority = 1100
    region = "osc_title"
    visible_blocker = true
    regex = ['^⚠[\u{fe0e}\u{fe0f}]?(?:\s|$)']

    [[rules]]
    id = "osc_title_working"
    state = "working"
    priority = 1050
    region = "osc_title"
    visible_working = true
    regex = ['^⏳[\u{fe0e}\u{fe0f}]?(?:\s|$)']

    # Hermes 0.23 busy composer placeholders (locales/en.yaml composer.placeholder_busy_*).
    # The TUI emits no OSC window title and no "ctrl+c to interrupt" hint, so these
    # three lines are the only live working signal on screen.
    [[rules]]
    id = "busy_steer_hint"
    state = "working"
    priority = 1060
    region = "bottom_non_empty_lines(14)"
    visible_working = true
    contains = ["type to steer this turn"]

    [[rules]]
    id = "busy_redirect_hint"
    state = "working"
    priority = 1060
    region = "bottom_non_empty_lines(14)"
    visible_working = true
    contains = ["type to redirect this turn"]

    [[rules]]
    id = "busy_queue_hint"
    state = "working"
    priority = 1060
    region = "bottom_non_empty_lines(14)"
    visible_working = true
    contains = ["type to queue a message for after this turn"]

    [[rules]]
    id = "dangerous_command_approval"
    state = "blocked"
    priority = 900
    region = "bottom_non_empty_lines(14)"
    visible_blocker = true
    any = [
      { contains = ["dangerous"] },
      { contains = ["approval"] },
      { contains = ["allow once", "deny"] },
      { line_regex = ['(?i)^\s*[▸>]?\s*1\.\s*allow'] },
    ]
    all = [
      { any = [{ contains = ["enter confirm"] }, { contains = ["enter to confirm"] }, { contains = ["↑/↓ to select"] }, { contains = ["show full command"] }] },
    ]

    [[rules]]
    id = "clarification_prompt"
    state = "blocked"
    priority = 900
    region = "bottom_non_empty_lines(14)"
    visible_blocker = true
    any = [
      { contains = ["hermes needs your"] },
      { line_regex = ['^\s*ask\s+\S'] },
      { contains = ["type your answer"] },
    ]
    all = [
      { any = [{ contains = ["enter confirm"] }, { contains = ["enter to confirm"] }, { contains = ["enter send"] }, { contains = ["press enter"] }, { contains = ["↑/↓ select"] }, { contains = ["↑/↓ to select"] }, { contains = ["other (type"] }] },
    ]

    [[rules]]
    id = "credential_prompt"
    state = "blocked"
    priority = 900
    region = "bottom_non_empty_lines(14)"
    visible_blocker = true
    any = [
      { contains = ["sudo password"] },
      { contains = ["skill setup"] },
      { contains = ["🔑", "for "] },
    ]

    [[rules]]
    id = "confirmation_prompt"
    state = "blocked"
    priority = 900
    region = "bottom_non_empty_lines(14)"
    visible_blocker = true
    all = [
      { any = [{ contains = ["approve once", "cancel"] }, { contains = ["start a new session", "keep going"] }] },
      { any = [{ contains = ["enter to confirm"] }, { contains = ["enter confirm"] }, { contains = ["type 1/2/3"] }, { contains = ["y/n quick"] }] },
    ]

    [[rules]]
    id = "interrupt_status_working"
    state = "working"
    priority = 950
    region = "bottom_non_empty_lines(5)"
    visible_working = true
    any = [
      { contains = ["msg=interrupt"] },
      { contains = ["ctrl+c to interrupt"] },
    ]

    [[rules]]
    id = "classic_cancel_working"
    state = "working"
    priority = 500
    region = "bottom_non_empty_lines(5)"
    visible_working = true
    contains = ["ctrl+c cancel"]

    [[rules]]
    id = "osc_title_idle"
    state = "idle"
    priority = 100
    region = "osc_title"
    visible_idle = true
    regex = ['^✓[\u{fe0e}\u{fe0f}]?(?:\s|$)']
  '';

  # ── Ghostty 默认启动 herdr ────────────────────────────────────
  programs.ghostty.settings.command = "${pkgs.herdr}/bin/herdr";
}
