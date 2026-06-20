#!/usr/bin/env python3
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))
from framework import PopLauncherPlugin


class ZellijPlugin(PopLauncherPlugin):
    """pop-launcher plugin for zellij session management."""

    description = "Attach or create zellij session"
    icon = "utilities-terminal"

    def __init__(self):
        # zellij plugin uses "e " prefix trigger (with trailing space)
        super().__init__(trigger="  ")

    def _list_sessions(self) -> list[str]:
        """List all zellij sessions."""
        try:
            result = subprocess.run(
                ["zellij", "list-sessions", "--no-formatting"],
                capture_output=True,
                text=True,
                timeout=2,
            )
            if result.returncode != 0:
                return []
            # Format: "name [Created X ago] (STATUS)"
            sessions = []
            for line in result.stdout.strip().split("\n"):
                if not line.strip():
                    continue
                name = line.split()[0].strip()
                if name:
                    sessions.append(name)
            return sessions
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return []

    def _build_list(self, keyword: str) -> list[tuple[str, bool]]:
        """Build filtered session list. Returns list of (name, is_new)."""
        keyword = keyword.strip()
        sessions = self._list_sessions()
        filtered = [s for s in sessions if keyword.lower() in s.lower()] if keyword else sessions

        # Add "create new" option if keyword is not empty and not in list
        is_new = bool(keyword and keyword not in sessions)
        result = [(s, False) for s in filtered]
        if is_new:
            result.append((keyword, True))
        return result

    def search(self, keyword: str) -> list[dict]:
        results = []
        for name, is_new in self._build_list(keyword):
            results.append({
                "name": f"📟 {name}",
                "description": "Create new session" if is_new else "Attach to session",
                "category": "Sessions",
                "keywords": ["zellij", "session"],
                "icon": {"Name": "list-add" if is_new else "utilities-terminal"},
                "_name": name,
                "_is_new": is_new,
            })
        return results

    def activate(self, item: dict, keyword: str) -> None:
        name = item["_name"]
        is_new = item["_is_new"]
        cmd = ["zellij", "attach", "--create", name] if is_new else ["zellij", "attach", name]

        env = os.environ.copy()
        subprocess.Popen(
            ["ghostty", "-e", *cmd],
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )


if __name__ == "__main__":
    ZellijPlugin().run()
