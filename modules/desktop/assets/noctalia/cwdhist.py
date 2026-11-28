#!/usr/bin/env python3
# Noctalia 最近目录 helper —— 由 modules/desktop/assets/pop-launcher/cwdhist/main.py 迁移
# 用法:
#   cwdhist.py list                 # 查 sqlite，输出 "PATH\t📁 name · ×N"（TAB 切标题/描述）
#   cwdhist.py open "<raw_line>"    # dmenu 形态：累加计数 + neovide 打开
#   cwdhist.py act <mode> <path>    # 二级菜单形态：累加计数 + 按 mode 打开
#       mode = herdr    在该目录新建/复用 herdr workspace 并切过去
#              neovide  启动 neovide
#              files    xdg-open（跟随默认文件管理器）
# 打开策略与计数都留在本脚本里：Luau provider 只把用户选定的一项传下来，
# 以后换打开方式只改这里。
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
        return ["neovide", "--maximized", "--vsync"]
    return shlex.split(os.environ.get("NV_OPEN_CMD", "ghostty -e nvim"))


def _expand(p: str) -> str:
    return p.replace("~", str(Path.home()), 1) if p.startswith("~") else p


def _clean(raw: str) -> str:
    """原始行 / 原始路径 → 真实路径（dmenu 会把整行回传，标题在 TAB 前）。"""
    return _expand(raw.split("\t")[0].strip())


def _bump(path: str) -> None:
    """访问计数 +1（与 shell cd 同源：绝对路径 upsert）。"""
    if not DB.exists():
        return
    conn = sqlite3.connect(DB)
    conn.execute(
        "INSERT INTO cwd_history (cwd, count) VALUES (?, 1) "
        "ON CONFLICT(cwd) DO UPDATE SET count = count + 1",
        (path,),
    )
    conn.commit()
    conn.close()


def _spawn(cmd, path: str) -> None:
    env = os.environ.copy()
    env["PWD"] = path
    subprocess.Popen(
        cmd,
        cwd=path,
        env=env,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def do_list():
    if not DB.exists():
        return
    conn = sqlite3.connect(DB)
    rows = conn.execute(
        "SELECT cwd, count FROM cwd_history ORDER BY count DESC LIMIT ?", (LIMIT,)
    ).fetchall()
    conn.close()
    for path, count in rows:
        # 保留 DB 原始形式（`~/...`）直接展示；打开时才 expand 成真实路径
        if not os.path.isdir(_expand(path)):
            continue
        # 一行一个候选；TAB 后是描述，Noctalia 显示标题+描述
        sys.stdout.write(f"{path}\t📁 {Path(path).name} · ×{count}\n")


def do_open(raw: str):
    path = _clean(raw)
    if not os.path.isdir(path):
        return
    _bump(path)
    _spawn(open_cmd(), path)


def do_act(mode: str, raw: str):
    path = _clean(raw)
    if not os.path.isdir(path):
        return
    cmd = {
        "herdr": ["herdr", "workspace", "create", "--cwd", path, "--focus"],
        "neovide": open_cmd(),
        "files": ["xdg-open", path],
    }.get(mode)
    if cmd is None:
        return
    _bump(path)
    _spawn(cmd, path)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "list":
        do_list()
    elif cmd == "open":
        do_open(sys.argv[2] if len(sys.argv) > 2 else "")
    elif cmd == "act" and len(sys.argv) > 3:
        do_act(sys.argv[2], sys.argv[3])
    elif cmd == "act":
        sys.exit("usage: cwdhist.py act <herdr|neovide|files> <path>")
    else:
        sys.exit("usage: cwdhist.py list | open <raw_line> | act <mode> <path>")