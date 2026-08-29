#!/usr/bin/env python3
"""Run YMC and provide a low-cost repeat fallback for its MPV backend."""

from __future__ import annotations

import json
import os
import select
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


SHELL_DIR = Path(__file__).resolve().parent
STATE_FILE = Path.home() / ".cache" / "tenebris" / "ymc-state.json"
BRIDGE = SHELL_DIR / "ymc-bridge.py"
STOP_REQUESTED = False


def request_stop(_signum: int, _frame: Any) -> None:
    global STOP_REQUESTED
    STOP_REQUESTED = True


def read_state() -> dict[str, Any]:
    try:
        payload = json.loads(STATE_FILE.read_text(encoding="utf-8"))
        return payload if isinstance(payload, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def repeat_mode(state: dict[str, Any]) -> str:
    mode = str(state.get("repeat", "off")).lower()
    return mode if mode in {"off", "all", "one"} else "off"


def repeat_target(state: dict[str, Any]) -> int | None:
    queue = state.get("queue", [])
    if not isinstance(queue, list) or not queue:
        return None
    try:
        current = max(0, min(len(queue) - 1, int(state.get("queuePosition", 0))))
    except (TypeError, ValueError):
        current = 0
    mode = repeat_mode(state)
    if mode == "one":
        return current
    if mode == "all":
        return (current + 1) % len(queue)
    return None


def quiet_run(args: list[str], timeout: float = 3) -> None:
    try:
        subprocess.run(
            args,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=timeout,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        pass


def player_status() -> str:
    try:
        return subprocess.check_output(
            ["playerctl", "--player", "mpv", "status"],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=2,
        ).strip()
    except (OSError, subprocess.SubprocessError):
        return "Stopped"


def apply_player_loop(mode: str) -> None:
    quiet_run([
        "playerctl", "--player", "mpv", "loop",
        "Track" if mode == "one" else "None",
    ])


def recover_finished_track() -> None:
    state = read_state()
    target = repeat_target(state)
    if target is None or player_status() != "Stopped":
        return
    quiet_run([sys.executable, str(BRIDGE), "play-index", str(target)], timeout=20)


def start_status_follower() -> subprocess.Popen[str] | None:
    try:
        return subprocess.Popen(
            ["playerctl", "--player", "mpv", "--follow", "status"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            bufsize=1,
        )
    except OSError:
        return None


def stop_process(process: subprocess.Popen[Any] | None) -> None:
    if process is None or process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=2)


def main() -> int:
    signal.signal(signal.SIGINT, request_stop)
    signal.signal(signal.SIGTERM, request_stop)

    engine = subprocess.Popen([
        "ymc", "--web-only", "--repeat", "off",
        "--web-host", "127.0.0.1", "--web-port", "47831",
    ])
    follower: subprocess.Popen[str] | None = None
    last_status = ""
    armed = False

    try:
        while not STOP_REQUESTED and engine.poll() is None:
            if follower is None or follower.poll() is not None:
                stop_process(follower)
                follower = start_status_follower()
                if follower is None or follower.stdout is None:
                    time.sleep(0.5)
                    continue

            ready, _, _ = select.select([follower.stdout], [], [], 0.75)
            if not ready:
                continue
            status = follower.stdout.readline().strip()
            if not status:
                stop_process(follower)
                follower = None
                if armed and last_status == "Playing":
                    # playerctl can reach EOF when MPV disappears without
                    # emitting a final Stopped line. Treat that edge as the
                    # same end-of-track event, but still let YMC react first.
                    time.sleep(0.55)
                    recover_finished_track()
                    armed = False
                time.sleep(0.25)
                continue

            mode = repeat_mode(read_state())
            if status == "Playing":
                apply_player_loop(mode)
                armed = True
            elif status == "Stopped" and armed and last_status == "Playing":
                # Give YMC's native queue handler first chance. The fallback
                # acts only if the MPV player remains stopped.
                time.sleep(0.55)
                recover_finished_track()
                armed = False
            last_status = status
    finally:
        stop_process(follower)
        stop_process(engine)

    return engine.returncode or 0


if __name__ == "__main__":
    raise SystemExit(main())
