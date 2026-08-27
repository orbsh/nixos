#!/usr/bin/env nu
# 窗口列表数据脚本 —— elephant 菜单 "windowsmru" 的数据源（MRU，最近使用优先，同 Alt+Tab）
# 输出：每行"窗口标题 \t app_id \t 窗口id"（TAB 分隔；value=窗口 id，供 Action 的 niri focus-window 用）
# 注意：elephant 常驻进程 env 无 NIRI_SOCKET / XDG_RUNTIME_DIR，须显式定位 niri IPC socket
def main [query: string] {
    let sock = glob /run/user/*/niri.wayland-*.sock | sort | last
    if ($sock | is-empty) or not ($sock | path exists) { return }
    $env.NIRI_SOCKET = $sock

    let wins = (niri msg -j windows | from json)

    # MRU：按 focus_timestamp 降序 = 最近使用优先；skip 1 = 剔除当前（最近焦点，必排第一）→ 第1项=上一个窗口（Alt+Tab 语义）
    let rows = $wins
    | sort-by { |w|
        ($w.focus_timestamp.secs | default 0) + ($w.focus_timestamp.nanos | default 0) / 1000000000.0
    } --reverse
    | skip 1
    | each { |w|
        let disp = if ($w.title | is-empty) { $w.app_id } else { $w.title }
        $"($disp)\t($w.app_id)\t($w.id)"
    }

    $rows | str join "\n"
}