#!/usr/bin/env python3
import os
import shlex
import sqlite3
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))
from framework import PopLauncherPlugin


class CwdHistPlugin(PopLauncherPlugin):
    description = "Open Neovide in recent work directory"
    icon = "folder"

    def __init__(self):
        super().__init__(trigger=" ")
        self.db_path = Path(
            os.environ.get("CWD_HISTORY_FILE", "~/.local/share/nushell/cwd_history.sqlite")
        ).expanduser()
        mode = os.environ.get("NV_MODE", "neovide")
        if mode == "neovide":
            self.open_cmd = ["neovide", "--maximized", "--frame", "none"]
        else:
            self.open_cmd = shlex.split(os.environ.get("NV_OPEN_CMD", "ghostty -e nvim"))

    @staticmethod
    def _expand(p: str) -> str:
        return p.replace("~", str(Path.home()), 1) if p.startswith("~") else p

    def _query(self, keyword: str, limit: int = 10) -> list[tuple[str, int]]:
        if not self.db_path.exists():
            return []
        conn = sqlite3.connect(self.db_path)
        rows = conn.execute(
            "SELECT cwd, count FROM cwd_history WHERE cwd LIKE ? ORDER BY count DESC LIMIT ?",
            (f"%{keyword}%", limit),
        ).fetchall()
        conn.close()
        return rows

    def search(self, keyword: str) -> list[dict]:
        results = []
        db_rows = self._query(keyword)
        db_paths = set()

        for path, count in db_rows:
            real = self._expand(path)
            db_paths.add(real)
            results.append({
                "name": f"📁 {Path(real).name}",
                "description": f"{path} (×{count})",
                "category": "Dirs",
                "keywords": ["dir", "cwd"],
                "icon": {"Name": "folder"},
                "_path": real,
            })

        # Direct open: if keyword is a valid path not in DB, add it
        if keyword and ("/" in keyword or "~" in keyword):
            real = self._expand(keyword)
            if os.path.isdir(real) and real not in db_paths:
                results.append({
                    "name": f"📂 {Path(real).name}",
                    "description": "Open directly",
                    "category": "Direct",
                    "keywords": ["dir", "direct"],
                    "icon": {"Name": "folder-open"},
                    "_path": real,
                })

        return results

    def activate(self, item: dict, keyword: str) -> None:
        path = item["_path"]
        if not os.path.isdir(path):
            return

        # Update DB count (works for both DB results and direct opens)
        conn = sqlite3.connect(self.db_path)
        conn.execute(
            "INSERT INTO cwd_history (cwd, count) VALUES (?, 1) ON CONFLICT(cwd) DO UPDATE SET count = count + 1",
            (path,),
        )
        conn.commit()
        conn.close()

        env = os.environ.copy()
        env["PWD"] = path
        subprocess.Popen(
            self.open_cmd,
            cwd=path,
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


if __name__ == "__main__":
    CwdHistPlugin().run()
