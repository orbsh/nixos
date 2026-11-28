#!/usr/bin/env python3
"""Noctalia launcher 的窗口 MRU 数据源（替掉内置 /win 的合成器顺序）。

niri 的 `niri msg --json windows` 每个窗口自带 focus_timestamp（上次获得焦点的时刻），
按它倒序就是 Alt+Tab 顺序 —— 不需要自己维护焦点历史。walker 时代的 menus:windowsmru
也是这么排的（见 modules/legacy/desktop/assets/elephant/scripts/windowsmru.py），
而 Noctalia 内置 /win 只按合成器上报顺序 + 模糊匹配，文档没有 MRU 承诺。

子命令：
  list          每行 "标题<TAB>app_id<TAB>窗口 id"，MRU 倒序，跳过当前焦点窗口
  focus <id>    niri msg action focus-window --id <id>

launcher 派生的进程没有 NIRI_SOCKET，须自己定位 socket。
仅用标准库 + niri 命令。
"""

import glob
import json
import re
import os
import subprocess
import sys


def locate_socket():
    socks = sorted(glob.glob("/run/user/*/niri.wayland-*.sock"))
    return socks[-1] if socks and os.path.exists(socks[-1]) else None


def _which_niri():
    import shutil
    found = shutil.which("niri")
    if found:
        return found
    for c in sorted(glob.glob("/etc/profiles/per-user/*/bin/niri")) + [
              "/run/current-system/sw/bin/niri",
              os.path.expanduser("~/.nix-profile/bin/niri")]:
        if c and os.path.exists(c):
            return c
    return None


def niri(args):
    sock = locate_socket()
    if not sock:
        return None
    env = dict(os.environ)
    env["NIRI_SOCKET"] = sock
    return subprocess.run([_which_niri() or "niri", "msg", *args], env=env,
                          capture_output=True, text=True, check=False)


def windows():
    r = niri(["-j", "windows"])
    if r is None or r.returncode != 0:
        return []
    try:
        wins = json.loads(r.stdout)
    except json.JSONDecodeError:
        return []
    wins.sort(key=_focus_ts, reverse=True)
    return wins


def _focus_ts(w):
    f = w.get("focus_timestamp") or {}
    return f.get("secs", 0) + f.get("nanos", 0) / 1_000_000_000.0


def _row(w, current):
    """标题前加标记：当前窗口 "* "，其余两个空格（等宽字体下对齐）。"""
    mark = "* " if current else "  "
    title = w.get("title") or w.get("app_id") or ""
    app = w.get("app_id") or ""
    # 描述列带上 #id：dmenu 的 exec 只能拿到"标题<TAB>描述"这段文本，
    # 窗口 id 必须跟着走（末尾 #<数字> 便于正则取回）。
    def esc(x):
        # exec 的 {selection} 由我们自己单引号包住，标题里的 ' 会闭合引号，换成同形 ’
        return x.replace("'", "\u2019")

    return "\t".join([esc(mark + title), esc(f"{app} · #{w.get('id')}")])


def do_list():
    """MRU 倒序，但当前窗口排最后并标 "* "——它已经在屏幕上，跳它等于没动作。

    启动器抢走键盘焦点时可能没有 is_focused 的窗口，此时退化为 MRU 第一名。
    """
    wins = windows()
    if not wins:
        return
    current = next((w for w in wins if w.get("is_focused")), wins[0])
    rows = [_row(w, False) for w in wins if w is not current]
    rows.append(_row(current, True))
    print("\n".join(rows))


def do_focus(selection):
    """selection 是启动器回传的整行（"标题<TAB>app · #id"），先取末尾 id，取不到再按标题找。"""
    selection = selection.rstrip("\n")
    m = re.search(r"#(\d+)\s*$", selection)
    win_id = m.group(1) if m else None
    if win_id is None:
        # 只回传了标题时按标题/app 精确匹配一次
        head = selection.split("\t")[0].strip()
        for w in windows():
            if (w.get("title") or w.get("app_id") or "").strip() == head:
                win_id = str(w.get("id"))
                break
    if not win_id or not win_id.isdigit():
        return
    niri(["action", "focus-window", "--id", win_id])


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        do_list()
    elif cmd == "focus" and len(sys.argv) > 2:
        do_focus(sys.argv[2])
    else:
        sys.exit('usage: winmru.py list | focus <window_id>')