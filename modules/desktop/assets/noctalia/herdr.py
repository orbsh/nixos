#!/usr/bin/env python3
# Noctalia 启动器 provider：herdr agent/workspace 菜单
# 由 modules/desktop/assets/elephant/scripts/{herdr.py,herdr-focus.py} 迁移（walker 时代），
# 行为等价：agents 在前、未被 agent 占用的 workspace 补在后，状态分组 + MRU 排序，
# 回车先提 Ghostty 窗口再让 herdr focus 对应 pane / workspace。
#
# 用法:
#   herdr.py list                # 每个候选一行 "title\t<desc>"（Noctalia 用 TAB 切标题/描述）
#   herdr.py focus "<raw_line>"  # 激活：把 NOCTALIA 传回的原样行解析回 value 再跳转
#
# 为什么 focus 要回查而不是直接读 value：Noctalia 的 dmenu provider 只把「原样行」交给
# exec，行里多一列 value 会被当成描述显示出来。所以这里重跑一次 list，用 (title, desc)
# 精确匹配出 value —— 数据源相同，只要菜单没关就必然命中。
# 仅用 Python 标准库；外部依赖 herdr 命令。
import glob
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import time

GHOSTTY_APP_ID = "com.mitchellh.ghostty"  # niri windows 里 ghostty 的 app-id（实测）

MRU_DB = os.path.join(os.environ.get("XDG_CACHE_HOME",
                                     os.path.expanduser("~/.cache")),
                      "herdr-menu", "mru.db")

# 状态分组：blocked 最前，其次 done，再次 working，其余在后
_STATUS_RANK = {"blocked": 0, "done": 1, "working": 2}


def _run_herdr(*args):
    herdr = shutil.which("herdr")
    if not herdr:
        return None
    out = subprocess.run([herdr, *args], capture_output=True, text=True)
    if out.returncode != 0:
        return None
    try:
        return json.loads(out.stdout)
    except json.JSONDecodeError:
        return None


def git_status(path):
    """短 git 状态：'分支 ↓1↑1+1-2~3' / '分支' / ''（非 git 目录）。

    符号：↓ 落后 upstream、↑ 领先 upstream、+ 暂存新增、- 暂存删除、
    ~ 暂存修改；N 为计数。
    """
    r = subprocess.run(["git", "-C", path, "status", "--porcelain=v1", "-b"],
                       capture_output=True, text=True, timeout=5)
    if r.returncode != 0:
        return ""
    b = subprocess.run(["git", "-C", path, "branch", "--show-current"],
                       capture_output=True, text=True, timeout=5)
    branch = b.stdout.strip()
    counts = {"↓": 0, "↑": 0, "+": 0, "-": 0, "~": 0}
    first = True
    for line in r.stdout.splitlines():
        if first:  # 首行 ## 分支信息，含 ahead/behind
            first = False
            m = re.search(r"ahead (\d+)", line)
            if m:
                counts["↑"] += int(m.group(1))
            m = re.search(r"behind (\d+)", line)
            if m:
                counts["↓"] += int(m.group(1))
            continue
        if not line.strip():
            continue
        x, y = line[0], line[1]  # X=暂存区状态，Y=工作区状态
        if x in "A?":
            counts["+"] += 1
        elif x == "D":
            counts["-"] += 1
        elif x in "MRT":
            counts["~"] += 1
        if y == "A":
            counts["+"] += 1
        elif y == "D":
            counts["-"] += 1
        elif y in "MRT":
            counts["~"] += 1
    symbols = "".join(f"{k}{v}" for k, v in counts.items() if v)
    return f"{branch} {symbols}".strip()


def _pane_cwd_map():
    """workspace_id → 首个 pane 的 cwd（无 agent 的 workspace 只能从 pane 反查）。"""
    data = _run_herdr("pane", "list")
    if data is None:
        return {}
    cwd_map = {}
    for p in (data.get("result") or {}).get("panes") or []:
        ws = p.get("workspace_id")
        cwd = p.get("cwd")
        if ws and cwd and ws not in cwd_map:
            cwd_map[ws] = cwd
    return cwd_map


def _ws_cwd(ws, cwd_map):
    return cwd_map.get(ws.get("workspace_id")) or ws.get("label")


def _mru_order():
    """value → MRU 序号（最近使用的最小）。库缺失/损坏返回空表，全部垫底。"""
    try:
        conn = sqlite3.connect(f"file:{MRU_DB}?mode=ro", uri=True)
        rows = conn.execute("SELECT value, ts FROM mru").fetchall()
        conn.close()
    except sqlite3.Error:
        return {}
    return {value: i for i, (value, _ts) in
            enumerate(sorted(rows, key=lambda r: -r[1]))}


def _rows():
    """(title, desc, value, status) 全量候选，已排序；过滤交给启动器自己。"""
    agent_data = _run_herdr("agent", "list")
    if agent_data is None:
        return []
    agents = (agent_data.get("result") or {}).get("agents") or []
    occupied = {a.get("workspace_id") for a in agents if a.get("workspace_id")}
    rows = []
    for a in agents:
        cwd_short = (a.get("cwd") or "?").rstrip("/").split("/")[-1]
        mark = "* " if a.get("focused") else ""
        a_type = a.get("agent")
        text = f"{mark}{cwd_short}" + (f" <{a_type}>" if a_type else "")
        sub = " -- ".join(s for s in [a.get("agent_status") or "unknown",
                                      git_status(a.get("cwd") or "")] if s)
        rows.append((text, sub, f"agent:{a.get('pane_id')}",
                     a.get("agent_status") or "unknown"))
    ws_data = _run_herdr("workspace", "list")
    panes = _pane_cwd_map()
    if ws_data is not None:
        for ws in (ws_data.get("result") or {}).get("workspaces") or []:
            if ws.get("workspace_id") in occupied:
                continue
            status = ws.get("agent_status") or "unknown"
            sub = " -- ".join(s for s in [status, git_status(_ws_cwd(ws, panes))] if s)
            mark = "* " if ws.get("focused") else ""
            rows.append((f"{mark}{ws['label']}", sub,
                         f"workspace:{ws['workspace_id']}", status))
    mru = _mru_order()
    rows.sort(key=lambda r: (0 if r[3] in ("done", "blocked") else 1,
                             _STATUS_RANK.get(r[3], 3),
                             r[0].startswith("* "),
                             mru.get(r[2], len(mru))))
    return rows


def do_list():
    for text, sub, _value, _status in _rows():
        print(f"{text}\t{sub}")


def _line_of(row):
    return f"{row[0]}\t{row[1]}"


def do_focus(selection):
    selection = selection.rstrip("\n")
    rows = _rows()
    value = next((r[2] for r in rows if _line_of(r) == selection), None)
    if value is None:  # 描述列可能被启动器裁掉时退回按标题匹配
        value = next((r[2] for r in rows if r[0] == selection.strip()), None)
    if value is None:
        return
    if _focus(value):
        mru_touch(value)


def _focus_ghostty_window():
    """先把 Ghostty 提到前台：herdr focus 只切内部 pane，窗口不在前台就看不见效果。

    NIRI_SOCKET 自举：本进程从启动器 exec 出来，env 里不一定有该变量。
    """
    env = dict(os.environ)
    if "NIRI_SOCKET" not in env:
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


def _focus(value):
    kind, _, target = value.partition(":")
    if kind not in ("agent", "workspace") or not target:
        return False
    _focus_ghostty_window()
    herdr = shutil.which("herdr")
    if not herdr:
        return False
    # herdr 0.9 multi-client：agent.focus 只更新焦点/seen，画面跟随 workspace.focus 事件，
    # 所以 agent 跳转要两步。
    if kind == "agent":
        ws_id = target.split(":")[0]
        subprocess.run([herdr, "agent", "focus", target], capture_output=True)
        r = subprocess.run([herdr, "workspace", "focus", ws_id], capture_output=True)
    else:
        r = subprocess.run([herdr, "workspace", "focus", target], capture_output=True)
    return r.returncode == 0


def mru_touch(value):
    """记录一次跳转（MRU）：upsert 时间戳。失败静默（MRU 是纯增益）。"""
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


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        do_list()
    elif cmd == "focus" and len(sys.argv) > 2:
        do_focus(sys.argv[2])
    else:
        sys.exit("usage: herdr.py list | herdr.py focus \"<raw_line>\"")