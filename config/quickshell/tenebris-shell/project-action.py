#!/usr/bin/env python3
"""Launch a bounded action below the selected TENEBRIS project root."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse


def project_path(raw: str, raw_root: str) -> Path:
    home = Path.home().resolve()
    root = Path(raw_root).expanduser().resolve()
    root.relative_to(home)
    path = Path(raw).expanduser().resolve()
    path.relative_to(root)
    if not path.is_dir():
        raise ValueError("project directory does not exist")
    return path


def github_remote_url(path: Path) -> str:
    try:
        raw = subprocess.check_output(
            ["git", "-C", str(path), "remote", "get-url", "origin"],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=1.5,
        ).strip()
    except (OSError, subprocess.SubprocessError):
        return ""

    if raw.startswith("git@github.com:"):
        repository = raw.split(":", 1)[1]
    else:
        parsed = urlparse(raw)
        if (parsed.hostname or "").lower() != "github.com":
            return ""
        repository = parsed.path
    repository = repository.strip("/")
    if repository.endswith(".git"):
        repository = repository[:-4]
    if repository.count("/") < 1:
        return ""
    return f"https://github.com/{repository}"


def main() -> int:
    if len(sys.argv) != 4:
        return 2

    action, raw_path, raw_root = sys.argv[1:]
    try:
        path = project_path(raw_path, raw_root)
    except (OSError, ValueError):
        return 2

    commands = {
        "editor": ["omarchy", "launch", "editor", str(path)],
        "terminal": [
            "uwsm", "app", "--", "xdg-terminal-exec", f"--dir={path}",
        ],
        "vscode": ["uwsm", "app", "--", "code", "--new-window", str(path)],
        "files": ["uwsm", "app", "--", "nautilus", "--new-window", str(path)],
        "codex": [
            "uwsm", "app", "--", "xdg-terminal-exec",
            "--app-id=tenebris-codex", f"--title=CODEX — {path.name}",
            f"--dir={path}", "--", "codex", "--yolo",
        ],
    }
    if action == "github":
        remote_url = github_remote_url(path)
        selected = ["omarchy", "launch", "browser", remote_url] if remote_url else None
    else:
        selected = commands.get(action)
    if selected is None:
        return 3
    if action == "codex" and shutil.which("codex") is None:
        return 3
    if action == "vscode" and shutil.which("code") is None:
        return 3
    os.execvp(selected[0], selected)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
