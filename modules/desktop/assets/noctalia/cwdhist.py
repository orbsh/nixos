#!/usr/bin/env python3
# Noctalia cwdhist provider —— 由 modules/desktop/assets/pop-launcher/cwdhist/main.py 迁移
# 用法:
#   cwdhist.py list                # 查 sqlite，输出 "PATH\t📁 name · ×N"（TAB 切标题/描述）
#   cwdhist.py open "<raw_line>"   # 打开选中的 cwd（累加计数 + neovide cwd 启动）
import os
import shlex
import sqlite3
import subprocess
import sys
from pathlib import Path

DB = Path(os.environ.get("CWD_HISTORY_FILE", "~/.local/share/nushell/cwd_history.sqlite")).expanduser()
LIMIT = 200


def open_cmd():
    mode = os.environ.get("NV_MODE", "neovide")
    if mode == "neovide":
        return ["neovide", "--maximized", "--frame", "none", "--vsync"]
    return shlex.split(os.environ.get("NV_OPEN_CMD", "ghostty -e nvim"))


def _expand(p: str) -> str:
    return p.replace("~", str(Path.home()), 1) if p.startswith("~") else p


def do_list():
    if not DB.exists():
        return
    conn = sqlite3.connect(DB)
    rows = conn.execute(
        "SELECT cwd, count FROM cwd_history ORDER BY count DESC LIMIT ?", (LIMIT,)
    ).fetchall()
    conn.close()
    for path, count in rows:
        # 保留 DB 原始形式（`~/...`）直接展示；open 时才 expand 成真实路径
        if not os.path.isdir(_expand(path)):
            continue
        # 一行一个候选；TAB 后是描述，Noctalia 显示标题+描述，选中原样返回整行
        sys.stdout.write(f"{path}\t📁 {Path(path).name} · ×{count}\n")


def do_open(raw: str):
    path = (raw.split("\t")[0] if "\t" in raw else raw).strip()
    path = _expand(path)
    if not os.path.isdir(path):
        return
    conn = sqlite3.connect(DB)
    conn.execute(
        "INSERT INTO cwd_history (cwd, count) VALUES (?, 1) "
        "ON CONFLICT(cwd) DO UPDATE SET count = count + 1",
        (path,),
    )
    conn.commit()
    conn.close()
    env = os.environ.copy()
    env["PWD"] = path
    subprocess.Popen(
        open_cmd(),
        cwd=path,
        env=env,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "list":
        do_list()
    elif cmd == "open":
        do_open(sys.argv[2] if len(sys.argv) > 2 else "")