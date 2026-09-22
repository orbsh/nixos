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
    new_tab = ["prefix+c", "ctrl+alt+t"]
    next_tab = ["prefix+n", "ctrl+alt+n"]
    previous_tab = ["prefix+p", "ctrl+alt+p"]
    close_pane = ["prefix+x", "ctrl+alt+x"]
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
    pane_borders = false
    pane_outer_borders = false
    pane_gaps = true

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

  # ── Ghostty 默认启动 herdr ────────────────────────────────────
  programs.ghostty.settings.command = "${pkgs.herdr}/bin/herdr";
}
