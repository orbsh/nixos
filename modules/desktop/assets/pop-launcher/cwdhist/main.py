#!/usr/bin/env python3
import json
import os
import shlex
import sqlite3
import subprocess
import sys
from pathlib import Path

# 模式：terminal (ghostty/alacritty + nvim) 或 neovide
MODE = os.environ.get("NV_MODE", "neovide")

if MODE == "neovide":
    OPEN_CMD = ["neovide", "--maximized", "--frame", "none"]
else:
    OPEN_CMD = shlex.split(os.environ.get("NV_OPEN_CMD", "ghostty -e nvim"))
DB_PATH = Path(os.environ.get("CWD_HISTORY_FILE", "~/.local/share/nushell/cwd_history.sqlite")).expanduser()
STATE_FILE = Path("/tmp/pop-nv-keyword")


def expand_path(p: str) -> str:
    return p.replace("~", str(Path.home()), 1) if p.startswith("~") else p


def query_paths(keyword: str, limit: int = 10) -> list[tuple[str, int]]:
    if not DB_PATH.exists():
        return []
    conn = sqlite3.connect(DB_PATH)
    rows = conn.execute(
        "SELECT cwd, count FROM cwd_history WHERE cwd LIKE ? ORDER BY count DESC LIMIT ?",
        (f"%{keyword}%", limit),
    ).fetchall()
    conn.close()
    return rows


def send(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def handle_search(query: str):
    if not query.startswith("  "):
        send("Finished")
        return
    keyword = query[2:]
    STATE_FILE.write_text(keyword)

    for i, (path, count) in enumerate(query_paths(keyword)):
        real = expand_path(path)
        send({
            "Append": {
                "id": i,
                "name": f"📁 {Path(real).name}",
                "description": f"{path} (×{count})",
                "category": "Dirs",
                "keywords": ["dir", "cwd"],
                "icon": {"Name": "folder"},
            }
        })
    send("Finished")


def handle_activate(item_id: int):
    keyword = STATE_FILE.read_text().strip() if STATE_FILE.exists() else ""
    rows = query_paths(keyword, limit=item_id + 1)

    send("Close")

    if item_id < len(rows):
        path = expand_path(rows[item_id][0])
        if os.path.isdir(path):
            # Upsert: 不存在则插入，存在则增加计数
            conn = sqlite3.connect(DB_PATH)
            conn.execute(
                "INSERT INTO cwd_history (cwd, count) VALUES (?, 1) ON CONFLICT(cwd) DO UPDATE SET count = count + 1",
                (rows[item_id][0],),
            )
            conn.commit()
            conn.close()

            env = os.environ.copy()
            env["PWD"] = path

            subprocess.Popen(
                OPEN_CMD,
                cwd=path,
                env=env,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError:
            continue

        if isinstance(req, dict) and "Search" in req:
            handle_search(req["Search"])
        elif isinstance(req, dict) and "Activate" in req:
            handle_activate(req["Activate"])


if __name__ == "__main__":
    main()
