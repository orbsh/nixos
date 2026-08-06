#!/usr/bin/env python3
"""Patch MPFB2 locationservice to honor the MPFB_SECOND_ROOT env var.

MPFB2 only reads its "second root" from the mpfb_second_root Blender preference,
which lives in userpref.blend and is not under Nix control. This patch makes the
env var take precedence so the Nix wrapper can point MPFB2 at a Nix-managed asset
library without touching the user's Blender preferences.

The replacement is line-based so the surrounding indentation is preserved exactly.

Usage: patch_mpfb_second_root.py <path-to-locationservice.py>
"""

import os
import re
import sys


OLD = 'self._second_root = get_preference("mpfb_second_root")'


def build_replacement(indent: str) -> str:
    return "\n".join(
        [
            indent + 'env_root = os.environ.get("MPFB_SECOND_ROOT", "").strip()',
            indent + "if env_root:",
            indent + "    self._second_root = os.path.abspath(os.path.expanduser(env_root))",
            indent + "else:",
            indent + "    " + 'self._second_root = get_preference("mpfb_second_root")',
        ]
    )


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2

    path = sys.argv[1]
    with open(path, encoding="utf-8") as handle:
        lines = handle.readlines()

    pattern = re.compile(r"^(\s*)" + re.escape(OLD) + r"\s*$")
    replaced = False
    for i, line in enumerate(lines):
        match = pattern.match(line)
        if match:
            indent = match.group(1)
            lines[i] = build_replacement(indent) + "\n"
            replaced = True
            break

    if not replaced:
        print(f"pattern not found in {path}; refusing to patch", file=sys.stderr)
        return 3

    with open(path, "w", encoding="utf-8") as handle:
        handle.writelines(lines)
    return 0


if __name__ == "__main__":
    sys.exit(main())
