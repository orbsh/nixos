#!/usr/bin/env python3
"""
pop-launcher plugin framework.

Base class for pop-launcher plugins. Subclasses implement `search()` and `activate()`.
"""
import json
import sys
from pathlib import Path


class PopLauncherPlugin:
    """
    pop-launcher plugin base class.

    Subclasses must implement:
    - search(keyword: str) -> list[dict]
    - activate(item: dict, keyword: str) -> None

    Optional overrides:
    - __init__(): customize trigger, state_file, etc.
    - description: plugin description for plugin.ron
    - icon: icon name for plugin.ron
    """

    description: str = ""
    icon: str = "folder"

    def __init__(self, trigger: str = "  ", state_file: Path | None = None):
        self.trigger = trigger
        # Auto-generate state_file path from class name
        self.state_file = state_file or Path(f"/tmp/pop-{self.__class__.__name__.lower()}-keyword")
        self._last_results: list[dict] = []

    @property
    def plugin_ron(self) -> str:
        """Generate plugin.ron content from trigger."""
        name = self.__class__.__name__.lower().replace("plugin", "")
        regex = f"^{self.trigger}.*" if self.trigger else ".*"
        return f'''(
    name: "{name}",
    description: "{self.description}",
    bin: (path: "main.py"),
    icon: Name("{self.icon}"),
    query: (
        regex: "{regex}",
        help: "{self.trigger}"
    )
)
'''

    def search(self, keyword: str) -> list[dict]:
        """Return search results as list of pop-launcher Append dicts."""
        raise NotImplementedError

    def activate(self, item: dict, keyword: str) -> None:
        """Handle selection event. item is the full dict from search()."""
        raise NotImplementedError

    # === Framework methods (subclasses usually don't override) ===

    def _send(self, obj):
        """Send JSON message to pop-launcher."""
        sys.stdout.write(json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n")
        sys.stdout.flush()

    def _handle_search(self, query: str):
        """Handle Search request, auto-handle trigger prefix and state persistence."""
        if not query.startswith(self.trigger):
            self._send("Finished")
            return

        keyword = query[len(self.trigger):]
        self.state_file.write_text(keyword)

        # Save full results and auto-inject id field
        self._last_results = self.search(keyword)
        for i, item in enumerate(self._last_results):
            item.setdefault("id", i)
            self._send({"Append": item})
        self._send("Finished")

    def _handle_activate(self, item_id: int):
        """Handle Activate request, auto-restore keyword and pass full item dict."""
        keyword = self.state_file.read_text().strip() if self.state_file.exists() else ""
        if item_id < len(self._last_results):
            self._send("Close")
            self.activate(self._last_results[item_id], keyword)

    def run(self):
        """Main loop: read stdin, dispatch to handlers."""
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                req = json.loads(line)
            except json.JSONDecodeError:
                continue

            if isinstance(req, dict) and "Search" in req:
                self._handle_search(req["Search"])
            elif isinstance(req, dict) and "Activate" in req:
                self._handle_activate(req["Activate"])
