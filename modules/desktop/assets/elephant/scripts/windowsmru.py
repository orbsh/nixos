#!/usr/bin/env python3
"""elephant 菜单 "windowsmru" 的数据源：窗口列表（MRU，最近使用优先，同 Alt+Tab）。

子命令：
  list <query>  输出 TAB 三列：窗口标题 <TAB> app_id <TAB> 窗口 id
                （value 列=窗口 id，供 Action 的 niri focus-window --id 用）

elephant 常驻进程 env 无 NIRI_SOCKET / XDG_RUNTIME_DIR，须显式定位 niri IPC socket。
仅用 Python 标准库（json/glob/subprocess），外部依赖 niri 命令。
"""
import glob
import json
import os
import subprocess
import sys


def locate_socket():
    socks = sorted(glob.glob("/run/user/*/niri.wayland-*.sock"))
    return socks[-1] if socks and os.path.exists(socks[-1]) else None


def list_windows(query):
    sock = locate_socket()
    if not sock:
        return
    env = dict(os.environ)
    env["NIRI_SOCKET"] = sock
    out = subprocess.run(
        ["niri", "msg", "-j", "windows"], env=env,
        capture_output=True, text=True, check=False,
    ).stdout
    try:
        wins = json.loads(out)
    except json.JSONDecodeError:
        return

    q = query.lower()

    def ts(w):
        f = w.get("focus_timestamp") or {}
        return f.get("secs", 0) + f.get("nanos", 0) / 1_000_000_000.0

    wins.sort(key=ts, reverse=True)
    rows = []
    for w in wins[1:]:  # skip 1 = 剔除当前焦点（最近，必排第一）→ 第 1 项 = 上一个窗口
        title = w.get("title") or ""
        app = w.get("app_id") or ""
        disp = title or app
        if q and q not in ((disp + " " + app).lower()):
            continue
        rows.append("\t".join([disp, app, str(w.get("id") or "")]))
    print("\n".join(rows))


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a:
        sys.exit(0)
    if a[0] == "list":
        list_windows(" ".join(a[1:]))