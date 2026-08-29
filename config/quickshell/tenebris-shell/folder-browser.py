#!/usr/bin/env python3
"""List user folders for the TENEBRIS Workbench picker."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def within_home(path: Path, home: Path) -> bool:
    try:
        path.relative_to(home)
        return True
    except ValueError:
        return False


def display_path(path: Path, home: Path) -> str:
    if path == home:
        return "~"
    return "~/" + str(path.relative_to(home))


def main() -> int:
    home = Path.home().resolve()
    requested = sys.argv[1] if len(sys.argv) > 1 else "~/Projects"
    try:
        current = Path(requested).expanduser().resolve()
    except OSError:
        current = home
    if not current.is_dir() or not within_home(current, home):
        current = home

    entries = []
    try:
        children = sorted(
            (
                child.resolve()
                for child in current.iterdir()
                if not child.name.startswith(".") and child.is_dir()
            ),
            key=lambda child: child.name.casefold(),
        )
        for child in children:
            if within_home(child, home):
                entries.append({
                    "name": child.name,
                    "path": str(child),
                    "displayPath": display_path(child, home),
                })
    except OSError:
        pass

    parent = current.parent if current != home else current
    if not within_home(parent, home):
        parent = home
    print(json.dumps({
        "path": str(current),
        "displayPath": display_path(current, home),
        "parent": str(parent),
        "canGoUp": current != home,
        "entries": entries,
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
