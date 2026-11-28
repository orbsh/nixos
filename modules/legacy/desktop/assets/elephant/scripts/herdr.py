#!/usr/bin/env python3
"""elephant 菜单 "herdr" 的数据源。

子命令：
  agents <query>  合并列表：agent 在前（herdr agent list），其后是未被任何
                  agent 占用的 workspace（herdr workspace list 按 workspace_id
                  去重）。TAB 四列：
                  <label> <TAB> <git符号状态 -- [<agent>] -- <状态>> <TAB> <value> <TAB> <状态>
                  排序：blocked → done → working → 其余，组内 focused 的（"* " 前缀）排同组末位。
                  agent 行 label = cwd 短名，agent 类型放副标题 <hermes>；
                  空 workspace 的 label = workspace label，无 <agent> 段。
                  git 符号：↓落后 ↑领先 +新增 -删除 ~修改（clean 只显示分支名，非 git 省略）。

Action 用 value 精确 focus（前缀区分 agent/workspace），避免同名 label 歧义。
elephant 常驻进程 env 无 shell alias，herdr 走 PATH 查找。
仅用 Python 标准库（json/subprocess），外部依赖 herdr 命令。
"""
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys

MRU_DB = os.path.join(os.environ.get("XDG_CACHE_HOME",
                                      os.path.expanduser("~/.cache")),
                      "herdr-menu", "mru.db")


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
    ~ 暂存修改、+N/-N/~N 为对应计数（工作区改动按同样符号小写后缀区分在
    porcelain 两列里，这里合并计数）。
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


# 状态分组：blocked 最前，其次 done，再次 working，其余在后
_STATUS_RANK = {"blocked": 0, "done": 1, "working": 2}


def list_agents(query):
    agent_data = _run_herdr("agent", "list")
    if agent_data is None:
        return
    agents = (agent_data.get("result") or {}).get("agents") or []
    occupied = {a.get("workspace_id") for a in agents if a.get("workspace_id")}
    rows = []
    for a in agents:
        cwd_short = (a.get("cwd") or "?").rstrip("/").split("/")[-1]
        # 两行格式：第一行 = 名字 <agent 类型>（无类型省略），第二行 = 状态 - git
        mark = "* " if a.get("focused") else ""
        a_type = a.get("agent")
        text = f"{mark}{cwd_short}" + (f" <{a_type}>" if a_type else "")
        sub = " -- ".join(s for s in [a.get("agent_status") or "unknown",
                                     git_status(a.get("cwd") or "")] if s)
        rows.append((text, sub,
                     f"agent:{a.get('pane_id')}",
                     a.get("agent_status") or "unknown"))
    # 未被 agent 占用的 workspace（去重：agent 已占用的跳过）；
    # cwd 从 pane list 反查（无 agent 的 workspace 只有 pane）
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
    _emit(rows, query)


def _pane_cwd_map():
    """workspace_id → 首个 pane 的 cwd（pane list 每项都有 cwd，覆盖无 agent 的 workspace）。"""
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
    """workspace → 代表性 cwd（pane 反查；失败退回 label）。"""
    return cwd_map.get(ws.get("workspace_id")) or ws.get("label")


def _mru_order():
    """value → MRU 序号（最近使用的最小）。库缺失/损坏返回空表，全部垫底。"""
    try:
        conn = sqlite3.connect(f"file:{MRU_DB}?mode=ro", uri=True)
        rows = conn.execute("SELECT value, ts FROM mru").fetchall()
        conn.close()
    except sqlite3.Error:
        return {}
    order = {}
    for i, (value, _ts) in enumerate(sorted(rows, key=lambda r: -r[1])):
        order[value] = i
    return order


def _emit(rows, query):
    if query:
        q = query.lower()
        rows = [r for r in rows if q in r[0].lower() or q in r[1].lower()]
    # 排序：状态分组（done/blocked 优先，_STATUS_RANK）→ 组内 focused 排末位
    # → MRU（最近使用在前，从未用过的垫底）。focused 先于 MRU：刚跳转过的
    # workspace MRU 最新，否则会排到最前。
    mru = _mru_order()
    rows.sort(key=lambda r: (0 if r[3] in ("done", "blocked") else 1,
                             _STATUS_RANK.get(r[3], 3),
                             r[0].startswith("* "),
                             mru.get(r[2], len(mru))))
    for text, subtext, value, _status in rows:
        print(f"{text}\t{subtext}\t{value}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "agents"
    query = sys.argv[2] if len(sys.argv) > 2 else ""
    list_agents(query)
