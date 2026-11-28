#!/usr/bin/env python3
"""walker herdr 菜单的 focus 动作：先把 Ghostty 窗口带到前台（niri），再 herdr focus。

用法：
  herdr-focus <value>     # value = "agent:<pane_id>" 或 "workspace:<ws_id>"
                          # （herdr.py 合并菜单输出的 value）

为什么需要 niri 前置：herdr focus 只切 herdr 内部 pane；若 Ghostty 窗口本身
不在前台，用户看到的还是别的窗口。先 `niri msg action focus-window` 把
Ghostty 提到前台，herdr 内部切换才有可见效果。
"""
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import time

GHOSTTY_APP_ID = "com.mitchellh.ghostty"  # niri windows 里 ghostty 的 app-id（实测）

MRU_DB = os.path.join(os.environ.get("XDG_CACHE_HOME",
                                      os.path.expanduser("~/.cache")),
                      "herdr-menu", "mru.db")


def mru_touch(value):
    """记录一次跳转（MRU）：upsert value 的时间戳。失败静默（MRU 是纯增益）。"""
    try:
        os.makedirs(os.path.dirname(MRU_DB), exist_ok=True)
        conn = sqlite3.connect(MRU_DB)
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("""CREATE TABLE IF NOT EXISTS mru(
                          value TEXT PRIMARY KEY,
                          ts REAL NOT NULL)""")
        conn.execute("""INSERT INTO mru(value, ts) VALUES(?, ?)
                          ON CONFLICT(value) DO UPDATE SET ts=excluded.ts""",
                     (value, time.time()))
        conn.commit()
        conn.close()
    except sqlite3.Error:
        pass


def focus_ghostty_window():
    # NIRI_SOCKET 自举：elephant 常驻进程 env 里没有该变量（继承自 systemd 而非
    # niri 会话），依赖继承环境会静默失败。同 windowsmru.lua 的做法，按
    # /run/user/$UID/niri.wayland-*.sock 自举（多实例取第一个）。
    env = dict(os.environ)
    if "NIRI_SOCKET" not in env:
        import glob
        socks = sorted(glob.glob(f"/run/user/{os.getuid()}/niri.wayland-*.sock"))
        if not socks:
            return
        env["NIRI_SOCKET"] = socks[0]
    r = subprocess.run(["niri", "msg", "--json", "windows"],
                       capture_output=True, text=True, env=env)
    if r.returncode != 0:
        return
    try:
        wins = json.loads(r.stdout)
    except json.JSONDecodeError:
        return
    for w in wins:
        if w.get("app_id") == GHOSTTY_APP_ID:
            subprocess.run(["niri", "msg", "action", "focus-window", "--id", str(w["id"])],
                           capture_output=True, env=env)
            return


def main():
    if len(sys.argv) != 2:
        sys.exit('usage: herdr-focus agent:<pane_id> | herdr-focus workspace:<ws_id>')
    value = sys.argv[1]
    kind, _, target = value.partition(":")
    if kind not in ("agent", "workspace") or not target:
        sys.exit(f"invalid value: {value}")
    focus_ghostty_window()
    herdr = shutil.which("herdr")
    if not herdr:
        sys.exit("herdr not found in PATH")
    # herdr 0.9 multi-client：agent.focus 只更新 server 焦点/seen 标记，不驱动
    # client 视图；画面跟随 workspace.focus 事件。故 agent 跳转 = agent.focus
    # （焦点落到 agent pane）+ workspace.focus（驱动画面切过去）两步。
    # workspace 跳转单独一步即可。
    if kind == "agent":
        ws_id = target.split(":")[0]
        subprocess.run([herdr, "agent", "focus", target], capture_output=True)
        r = subprocess.run([herdr, "workspace", "focus", ws_id], capture_output=True)
    else:
        r = subprocess.run([herdr, "workspace", "focus", target], capture_output=True)
    if r.returncode == 0:
        mru_touch(value)


if __name__ == "__main__":
    main()
