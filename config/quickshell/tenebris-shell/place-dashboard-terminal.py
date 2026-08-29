#!/usr/bin/env python3
"""Fit the registered dashboard terminal to its live QML frame."""

from __future__ import annotations

import json
import math
import subprocess
import time


TERMINAL_CLASS = "tenebris-terminal"
FRAME_X = 125
FRAME_Y = 96
SURFACE_INSET_X = 6
HEADER_DIVIDER_Y = 35
SURFACE_BOTTOM_INSET = 6


def hypr_json(command: str) -> object:
    output = subprocess.check_output(["hyprctl", command, "-j"], text=True)
    return json.loads(output)


def dispatch(expression: str) -> None:
    subprocess.run(
        ["hyprctl", "dispatch", expression],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


clients = hypr_json("clients")
terminal = next(
    (client for client in clients if client.get("class") == TERMINAL_CLASS),
    None,
)
if terminal is None:
    raise SystemExit(0)

monitor_id = terminal.get("monitor")
monitors = hypr_json("monitors")
monitor = next(
    (item for item in monitors if item.get("id") == monitor_id),
    None,
)
if monitor is None:
    raise SystemExit(0)

# Hyprland reports output modes in physical pixels and layout positions in
# logical pixels. QML panel geometry uses those same logical dimensions.
scale = float(monitor.get("scale") or 1.0)
monitor_width = float(monitor["width"]) / scale
monitor_height = float(monitor["height"]) / scale

right_column_width = max(250.0, monitor_width * 0.18)
central_width = monitor_width - 156.0 - right_column_width
frame_width = central_width * 0.535
frame_height = (monitor_height - 114.0) * 0.55

x = int(monitor.get("x", 0)) + FRAME_X + SURFACE_INSET_X
y = int(monitor.get("y", 0)) + FRAME_Y + HEADER_DIVIDER_Y
width = max(1, math.floor(frame_width - SURFACE_INSET_X * 2.0 + 0.5))
height = max(
    1,
    math.floor(
        frame_height - HEADER_DIVIDER_Y - SURFACE_BOTTOM_INSET + 0.5
    ),
)
selector = f"class:{TERMINAL_CLASS}"

# A terminal may acknowledge the first configure while an output mode itself
# is still settling. Verify the compositor box and repeat once when that race
# leaves a one-pixel stale size.
for attempt in range(2):
    dispatch(
        "hl.dsp.window.resize({ "
        f"x = {width}, y = {height}, relative = false, window = \"{selector}\""
        " })"
    )
    dispatch(
        "hl.dsp.window.move({ "
        f"x = {x}, y = {y}, relative = false, window = \"{selector}\""
        " })"
    )
    if attempt == 1:
        break
    time.sleep(0.06)
    current = next(
        (
            client
            for client in hypr_json("clients")
            if client.get("class") == TERMINAL_CLASS
        ),
        None,
    )
    if current is not None and current.get("at") == [x, y] and current.get(
        "size"
    ) == [width, height]:
        break
