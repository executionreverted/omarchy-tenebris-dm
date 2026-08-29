#!/usr/bin/env python3
"""Control and reveal the selected TENEBRIS music provider."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import tempfile
import time
from pathlib import Path


STATE_FILE = Path.home() / ".cache" / "tenebris" / "music-provider.json"
YMC_STATE_FILE = Path.home() / ".cache" / "tenebris" / "ymc-state.json"
SHELL_DIR = Path(__file__).resolve().parent
CLIAMP_TMUX_SERVER = "tenebris-cliamp"
CLIAMP_TMUX_SESSION = "player"
PROVIDERS = {
    "ymc": {
        "binary": "ymc",
        "class": "tenebris-ymc",
        "unit": "tenebris-ymc.service",
        "stowed": "special:tenebris-ymc",
    },
    "cliamp": {
        "binary": "cliamp",
        "class": "tenebris-cliamp",
        "unit": "tenebris-cliamp.service",
        "stowed": "special:tenebris-cliamp",
    },
}


def output(args: list[str], default: str = "", timeout: float = 2) -> str:
    try:
        return subprocess.check_output(
            args,
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=timeout,
        ).strip()
    except (OSError, subprocess.SubprocessError):
        return default


def run(args: list[str]) -> None:
    try:
        subprocess.run(
            args,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=3,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        pass


def spawn(args: list[str]) -> None:
    try:
        subprocess.Popen(
            args,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError:
        pass


def available(provider: str) -> bool:
    return provider in PROVIDERS and shutil.which(PROVIDERS[provider]["binary"]) is not None


def active_provider() -> str:
    try:
        provider = str(json.loads(STATE_FILE.read_text(encoding="utf-8")).get("active", ""))
    except (OSError, json.JSONDecodeError, AttributeError):
        provider = ""
    if available(provider):
        return provider
    return next((name for name in ("ymc", "cliamp") if available(name)), "")


def save_active(provider: str) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps({"active": provider}, ensure_ascii=False) + "\n"
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=STATE_FILE.parent,
        prefix="music-provider-",
        delete=False,
    ) as temporary:
        temporary.write(payload)
        temporary_path = Path(temporary.name)
    temporary_path.replace(STATE_FILE)


def clients() -> list[dict]:
    try:
        value = json.loads(output(["hyprctl", "clients", "-j"], "[]"))
        return value if isinstance(value, list) else []
    except json.JSONDecodeError:
        return []


def provider_client(provider: str) -> dict | None:
    player_class = PROVIDERS[provider]["class"]
    return next((item for item in clients() if item.get("class") == player_class), None)


def backend_alive(provider: str) -> bool:
    if provider == "cliamp":
        return subprocess.run(
            [
                "tmux", "-L", CLIAMP_TMUX_SERVER,
                "has-session", "-t", CLIAMP_TMUX_SESSION,
            ],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        ).returncode == 0
    return output([
        "systemctl", "--user", "is-active", PROVIDERS[provider]["unit"]
    ]) == "active"


def ensure_backend(provider: str) -> bool:
    if backend_alive(provider):
        return True
    action = "restart" if provider == "cliamp" else "start"
    run(["systemctl", "--user", action, PROVIDERS[provider]["unit"]])
    for _attempt in range(40):
        if backend_alive(provider):
            return True
        time.sleep(0.1)
    return False


def ensure_provider_window(provider: str) -> dict | None:
    client = provider_client(provider)
    if client:
        return client
    if provider != "cliamp" or not ensure_backend(provider):
        return None
    spawn([
        "uwsm", "app", "--", "xdg-terminal-exec",
        "--app-id=tenebris-cliamp",
        "--title=TENEBRIS CLIAMP PLAYER",
        "--", "tmux", "-L", CLIAMP_TMUX_SERVER,
        "attach-session", "-t", CLIAMP_TMUX_SESSION,
    ])
    for _attempt in range(80):
        client = provider_client(provider)
        if client:
            return client
        time.sleep(0.1)
    return None


def dispatch(expression: str) -> None:
    run(["hyprctl", "dispatch", expression])


def stow(provider: str) -> None:
    client = provider_client(provider)
    if not client:
        return
    address = str(client.get("address", ""))
    workspace = str(client.get("workspace", {}).get("name", ""))
    if not address or workspace.startswith("special:"):
        return
    dispatch(
        "hl.dsp.window.move({ workspace = "
        + repr(PROVIDERS[provider]["stowed"])
        + ", follow = false, window = hl.get_window("
        + repr(f"address:{address}")
        + ") })"
    )


def pause(provider: str) -> None:
    if provider == "cliamp":
        run(["cliamp", "pause"])
    elif provider == "ymc":
        run(["playerctl", "--player", "mpv", "pause"])


def select(provider: str) -> bool:
    if not available(provider):
        return False
    save_active(provider)
    for other in PROVIDERS:
        if other != provider:
            pause(other)
            stow(other)
    return ensure_backend(provider)


def toggle(provider: str) -> int:
    if not select(provider):
        return 1
    # YMC is a lightweight web-only engine. Quickshell owns its handcrafted
    # overlay, so selecting it requires no second terminal/window process.
    if provider == "ymc":
        return 0
    client = ensure_provider_window(provider)
    if not client:
        return 1

    address = str(client.get("address", ""))
    if not address:
        return 1
    selector = f"address:{address}"
    try:
        active_workspace = str(json.loads(output(["hyprctl", "activeworkspace", "-j"], "{}"))["name"])
    except (json.JSONDecodeError, KeyError, TypeError):
        active_workspace = "1"
    current_workspace = str(client.get("workspace", {}).get("name", ""))
    if current_workspace == active_workspace:
        stow(provider)
        return 0

    dispatch(
        "hl.dsp.window.move({ workspace = "
        + repr(active_workspace)
        + ", follow = false, window = hl.get_window("
        + repr(selector)
        + ") })"
    )
    run([
        "hyprctl",
        "eval",
        "hl.dispatch(hl.dsp.focus({ window = hl.get_window("
        + repr(selector)
        + ") }))",
    ])
    return 0


def control(action: str) -> int:
    provider = active_provider()
    if not provider:
        return 1
    if provider == "cliamp":
        if not ensure_backend(provider):
            return 1
        command = {
            "play-pause": "toggle",
            "next": "next",
            "previous": "prev",
            "repeat": "repeat",
        }.get(action)
        if not command:
            return 2
        cliamp_args = ["cliamp", command]
        if action == "repeat":
            cliamp_args.append("cycle")
        run(cliamp_args)
        return 0

    if not ensure_backend(provider):
        return 1
    if action == "play-pause":
        mpv_players = output(["playerctl", "-l"]).splitlines()
        mpv_player = next(
            (item for item in mpv_players if item == "mpv" or item.startswith("mpv.")),
            "",
        )
        # YMC keeps an idle MPV/MPRIS process alive between tracks. A Stopped
        # player has no playlist to toggle, so restore the last cached queue
        # item instead of sending a no-op play-pause command.
        status = output(["playerctl", "--player", mpv_player, "status"]) if mpv_player else ""
        if status in {"Playing", "Paused"}:
            run(["playerctl", "--player", mpv_player, "play-pause"])
            return 0
        try:
            state = json.loads(YMC_STATE_FILE.read_text(encoding="utf-8"))
            position = int(state.get("queuePosition", 0))
        except (OSError, json.JSONDecodeError, TypeError, ValueError):
            position = 0
        run(["python3", str(SHELL_DIR / "ymc-bridge.py"), "play-index", str(position)])
        return 0
    category = {
        "next": "NEXT",
        "previous": "PREVIOUS",
        "repeat": "TOGGLE_REPEAT",
    }.get(action)
    if not category:
        return 2
    run(["python3", str(SHELL_DIR / "ymc-bridge.py"), "command", category])
    return 0


def seek(seconds: float) -> int:
    provider = active_provider()
    if provider == "cliamp":
        try:
            status = json.loads(output(["cliamp", "status", "--json"], "{}"))
            current = float(status.get("position", 0))
        except (json.JSONDecodeError, TypeError, ValueError):
            current = 0
        run(["cliamp", "seek", str(seconds - current)])
        return 0
    if provider == "ymc":
        run(["playerctl", "--player", "mpv", "position", str(seconds)])
        return 0
    return 1


def metadata(kind: str, value: str, url: str, artist: str, album: str, duration: float) -> int:
    provider = active_provider()
    if provider != "ymc":
        return toggle(provider) if provider else 1
    if kind == "title" and url:
        run([
            "python3", str(SHELL_DIR / "ymc-bridge.py"), "play-track",
            url, value, artist, album, str(duration),
        ])
    elif value.strip():
        run(["python3", str(SHELL_DIR / "ymc-bridge.py"), "search-play", value.strip()])
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    toggle_parser = subparsers.add_parser("toggle")
    toggle_parser.add_argument("provider", choices=PROVIDERS)

    control_parser = subparsers.add_parser("control")
    control_parser.add_argument("action", choices=("previous", "play-pause", "next", "repeat"))

    seek_parser = subparsers.add_parser("seek")
    seek_parser.add_argument("seconds", type=float)

    metadata_parser = subparsers.add_parser("metadata")
    metadata_parser.add_argument("kind", choices=("title", "artist", "album"))
    metadata_parser.add_argument("value")
    metadata_parser.add_argument("url")
    metadata_parser.add_argument("artist")
    metadata_parser.add_argument("album")
    metadata_parser.add_argument("duration", type=float)

    select_parser = subparsers.add_parser("select")
    select_parser.add_argument("provider", choices=PROVIDERS)

    args = parser.parse_args()
    if args.command == "toggle":
        return toggle(args.provider)
    if args.command == "control":
        return control(args.action)
    if args.command == "seek":
        return seek(args.seconds)
    if args.command == "metadata":
        return metadata(args.kind, args.value, args.url, args.artist, args.album, args.duration)
    if args.command == "select":
        return 0 if select(args.provider) else 1
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
