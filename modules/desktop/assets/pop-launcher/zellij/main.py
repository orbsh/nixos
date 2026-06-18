#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path

STATE_FILE = Path("/tmp/pop-zellij-keyword")


def list_sessions() -> list[str]:
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
        # 解析输出，只提取 session 名字
        # 格式: "name [Created X ago] (STATUS)"
        sessions = []
        for line in result.stdout.strip().split("\n"):
            if not line.strip():
                continue
            # 提取第一个空格前的内容作为 session 名字
            name = line.split()[0].strip()
            if name:
                sessions.append(name)
        return sessions
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return []


def send(obj):
    """Send JSON response to pop-launcher."""
    sys.stdout.write(json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def handle_search(query: str):
    """Handle search request."""
    keyword = query.strip()
    STATE_FILE.write_text(keyword)

    sessions = list_sessions()

    # Filter sessions by keyword
    filtered = [s for s in sessions if keyword.lower() in s.lower()] if keyword else sessions

    # Add "create new" option if keyword is not empty and not in list
    if keyword and keyword not in sessions:
        filtered.append(f"+ {keyword} (create)")

    for i, session in enumerate(filtered):
        is_new = session.startswith("+ ")
        name = session[2:] if is_new else session
        icon = "folder-new" if is_new else "utilities-terminal"

        send({
            "Append": {
                "id": i,
                "name": f"📟 {name}",
                "description": "Create new session" if is_new else "Attach to session",
                "category": "Sessions",
                "keywords": ["zellij", "session"],
                "icon": {"Name": icon},
            }
        })

    send("Finished")


def handle_activate(item_id: int):
    """Handle activate request."""
    keyword = STATE_FILE.read_text().strip() if STATE_FILE.exists() else ""
    sessions = list_sessions()

    # Filter sessions by keyword
    filtered = [s for s in sessions if keyword.lower() in s.lower()] if keyword else sessions

    # Add "create new" option if keyword is not empty and not in list
    if keyword and keyword not in sessions:
        filtered.append(f"+ {keyword} (create)")

    send("Close")

    if item_id < len(filtered):
        session = filtered[item_id]
        is_new = session.startswith("+ ")
        name = session[2:] if is_new else session

        # Build command
        if is_new:
            cmd = ["zellij", "attach", "--create", name]
        else:
            cmd = ["zellij", "attach", name]

        # Launch in terminal
        env = os.environ.copy()
        subprocess.Popen(
            ["ghostty", "-e", *cmd],
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )


def main():
    """Main loop."""
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
