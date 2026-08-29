#!/usr/bin/env python3
"""Send small commands to the persistent TENEBRIS YMC web companion."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import socket
import struct
import subprocess
import sys
import time
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse


HOST = "127.0.0.1"
PORT = 47831
PATH = "/ws"
GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
STATE_CACHE = Path.home() / ".cache" / "tenebris" / "ymc-state.json"
YMC_CONFIG = Path.home() / ".youtube-music-cli" / "config.json"


class BridgeError(RuntimeError):
    """A user-facing YMC bridge failure."""


class WebSocketClient:
    def __init__(self, sock: socket.socket) -> None:
        self.sock = sock

    @classmethod
    def connect(cls, timeout: float = 3.0) -> "WebSocketClient":
        sock = socket.create_connection((HOST, PORT), timeout=timeout)
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        request = (
            f"GET {PATH} HTTP/1.1\r\n"
            f"Host: {HOST}:{PORT}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n\r\n"
        )
        sock.sendall(request.encode("ascii"))

        response = bytearray()
        while b"\r\n\r\n" not in response:
            chunk = sock.recv(4096)
            if not chunk:
                raise BridgeError("YMC closed the WebSocket handshake")
            response.extend(chunk)
            if len(response) > 32768:
                raise BridgeError("YMC returned an oversized handshake")

        header = bytes(response).split(b"\r\n\r\n", 1)[0]
        lines = header.decode("latin-1").split("\r\n")
        if not lines or " 101 " not in lines[0]:
            raise BridgeError(f"YMC WebSocket handshake failed: {lines[0] if lines else 'empty response'}")

        headers = {}
        for line in lines[1:]:
            if ":" in line:
                name, value = line.split(":", 1)
                headers[name.strip().lower()] = value.strip()
        expected = base64.b64encode(hashlib.sha1((key + GUID).encode()).digest()).decode()
        if headers.get("sec-websocket-accept") != expected:
            raise BridgeError("YMC returned an invalid WebSocket accept key")

        return cls(sock)

    def close(self) -> None:
        try:
            self._send_frame(b"", opcode=0x8)
        except OSError:
            pass
        self.sock.close()

    def send_json(self, payload: dict[str, Any]) -> None:
        self._send_frame(json.dumps(payload, separators=(",", ":")).encode("utf-8"))

    def receive_json(self, timeout: float) -> dict[str, Any]:
        self.sock.settimeout(timeout)
        while True:
            opcode, payload = self._receive_frame()
            if opcode == 0x1:
                return json.loads(payload.decode("utf-8"))
            if opcode == 0x8:
                raise BridgeError("YMC closed the WebSocket connection")
            if opcode == 0x9:
                self._send_frame(payload, opcode=0xA)

    def _send_frame(self, payload: bytes, opcode: int = 0x1) -> None:
        mask = os.urandom(4)
        length = len(payload)
        header = bytearray([0x80 | opcode])
        if length < 126:
            header.append(0x80 | length)
        elif length <= 0xFFFF:
            header.append(0x80 | 126)
            header.extend(struct.pack("!H", length))
        else:
            header.append(0x80 | 127)
            header.extend(struct.pack("!Q", length))
        masked = bytes(value ^ mask[index % 4] for index, value in enumerate(payload))
        self.sock.sendall(bytes(header) + mask + masked)

    def _receive_frame(self) -> tuple[int, bytes]:
        first, second = self._receive_exact(2)
        opcode = first & 0x0F
        masked = bool(second & 0x80)
        length = second & 0x7F
        if length == 126:
            length = struct.unpack("!H", self._receive_exact(2))[0]
        elif length == 127:
            length = struct.unpack("!Q", self._receive_exact(8))[0]
        mask = self._receive_exact(4) if masked else b""
        payload = self._receive_exact(length)
        if masked:
            payload = bytes(value ^ mask[index % 4] for index, value in enumerate(payload))
        return opcode, payload

    def _receive_exact(self, length: int) -> bytes:
        data = bytearray()
        while len(data) < length:
            chunk = self.sock.recv(length - len(data))
            if not chunk:
                raise BridgeError("YMC WebSocket connection ended unexpectedly")
            data.extend(chunk)
        return bytes(data)


def connect_with_service_start() -> WebSocketClient:
    last_error: Exception | None = None
    for attempt in range(12):
        try:
            return WebSocketClient.connect()
        except (OSError, BridgeError) as error:
            last_error = error
            if attempt == 0:
                subprocess.run(
                    ["systemctl", "--user", "start", "tenebris-ymc.service"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    check=False,
                )
            time.sleep(0.25)
    raise BridgeError(f"Persistent YMC service is unavailable: {last_error}")


def video_id_from_url(value: str) -> str:
    candidate = value.strip()
    if candidate and "/" not in candidate and "?" not in candidate:
        return candidate
    parsed = urlparse(candidate)
    if parsed.netloc.lower().endswith("youtu.be"):
        return parsed.path.strip("/").split("/", 1)[0]
    if parsed.netloc.lower().endswith("youtube.com"):
        return parse_qs(parsed.query).get("v", [""])[0]
    return ""


def repeat_mode(state: dict[str, Any]) -> str:
    value = str(state.get("repeat", "")).lower()
    if value in {"off", "all", "one"}:
        return value
    try:
        config = json.loads(YMC_CONFIG.read_text(encoding="utf-8"))
        value = str(config.get("repeat", "off")).lower()
    except (OSError, json.JSONDecodeError, AttributeError):
        value = "off"
    return value if value in {"off", "all", "one"} else "off"


def next_repeat_mode(state: dict[str, Any]) -> str:
    modes = ("off", "all", "one")
    current = repeat_mode(state)
    return modes[(modes.index(current) + 1) % len(modes)]


def apply_repeat_to_player(mode: str) -> None:
    try:
        subprocess.run(
            [
                "playerctl", "--player", "mpv", "loop",
                "Track" if mode == "one" else "None",
            ],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=3,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        pass


def write_cached_state(state: dict[str, Any]) -> None:
    STATE_CACHE.parent.mkdir(parents=True, exist_ok=True)
    state["updatedAt"] = int(time.time())
    temporary = STATE_CACHE.with_suffix(".tmp")
    temporary.write_text(json.dumps(state, ensure_ascii=False), encoding="utf-8")
    temporary.replace(STATE_CACHE)


def write_state(queue: list[dict[str, Any]], position: int) -> None:
    previous = read_state()
    payload: dict[str, Any] = {
        "queue": queue,
        "queuePosition": position,
        "currentTrack": queue[position] if 0 <= position < len(queue) else None,
        "repeat": repeat_mode(previous),
    }
    write_cached_state(payload)


def read_state() -> dict[str, Any]:
    try:
        value = json.loads(STATE_CACHE.read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def play_track(client: WebSocketClient, track: dict[str, Any], queue: list[dict[str, Any]] | None = None, position: int = 0) -> None:
    tracks = queue or [track]
    client.send_json({"type": "command", "action": {"category": "SET_QUEUE", "queue": tracks}})
    client.send_json({"type": "command", "action": {"category": "PLAY", "track": track}})
    write_state(tracks, position)
    apply_repeat_to_player(repeat_mode(read_state()))


def search_and_play(client: WebSocketClient, query: str) -> None:
    client.send_json({"type": "search-request", "query": query, "searchType": "songs"})
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        message = client.receive_json(max(0.1, deadline - time.monotonic()))
        if message.get("type") == "error":
            raise BridgeError(str(message.get("error") or "YMC search failed"))
        if message.get("type") != "search-results":
            continue
        tracks = [
            result.get("data")
            for result in message.get("results", [])
            if result.get("type") == "song" and isinstance(result.get("data"), dict)
        ][:12]
        if not tracks:
            raise BridgeError(f"YMC found no playable tracks for: {query}")
        play_track(client, tracks[0], tracks, 0)
        print(json.dumps({"ok": True, "track": tracks[0]}, ensure_ascii=False))
        return
    raise BridgeError("YMC search timed out")


def send_command(client: WebSocketClient, category: str) -> None:
    if category == "TOGGLE_REPEAT":
        state = read_state()
        state["repeat"] = next_repeat_mode(state)
        write_cached_state(state)
        apply_repeat_to_player(state["repeat"])
        print(json.dumps({"ok": True, "command": category, "repeat": state["repeat"]}))
        return

    if category in {"NEXT", "PREVIOUS"}:
        state = read_state()
        queue = state.get("queue", [])
        position = int(state.get("queuePosition", 0))
        target = position + (1 if category == "NEXT" else -1)
        if isinstance(queue, list) and queue and repeat_mode(state) == "all":
            target %= len(queue)
        if isinstance(queue, list) and 0 <= target < len(queue):
            track = queue[target]
            if isinstance(track, dict):
                play_track(client, track, queue, target)
                print(json.dumps({"ok": True, "command": category, "track": track}, ensure_ascii=False))
                return
    client.send_json({"type": "command", "action": {"category": category}})
    print(json.dumps({"ok": True, "command": category}))


def play_cached_index(client: WebSocketClient, index: int) -> None:
    state = read_state()
    queue = state.get("queue", [])
    if not isinstance(queue, list) or not 0 <= index < len(queue):
        raise BridgeError(f"YMC queue index is unavailable: {index}")
    track = queue[index]
    if not isinstance(track, dict):
        raise BridgeError(f"YMC queue entry is invalid: {index}")
    play_track(client, track, queue, index)
    print(json.dumps({"ok": True, "track": track, "index": index}, ensure_ascii=False))


def play_explicit_track(
    client: WebSocketClient,
    media_url: str,
    title: str,
    artist: str,
    album: str,
    duration: float,
) -> None:
    video_id = video_id_from_url(media_url)
    if not video_id:
        raise BridgeError("The current canticle has no YouTube video id")
    artists = [{"artistId": "", "name": artist or "Unknown Artist"}]
    track: dict[str, Any] = {
        "videoId": video_id,
        "title": title or video_id,
        "artists": artists,
        "duration": max(0, round(duration)),
    }
    if album:
        track["album"] = {"albumId": "", "name": album, "artists": artists}
    play_track(client, track)
    print(json.dumps({"ok": True, "track": track}, ensure_ascii=False))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="action", required=True)
    search_parser = subparsers.add_parser("search-play")
    search_parser.add_argument("query")
    play_parser = subparsers.add_parser("play-track")
    play_parser.add_argument("media_url")
    play_parser.add_argument("title")
    play_parser.add_argument("artist")
    play_parser.add_argument("album")
    play_parser.add_argument("duration", type=float)
    command_parser = subparsers.add_parser("command")
    command_parser.add_argument(
        "category",
        choices=("PAUSE", "RESUME", "NEXT", "PREVIOUS", "TOGGLE_REPEAT"),
    )
    index_parser = subparsers.add_parser("play-index")
    index_parser.add_argument("index", type=int)
    subparsers.add_parser("health")
    args = parser.parse_args()

    client = connect_with_service_start()
    try:
        if args.action == "search-play":
            search_and_play(client, args.query.strip())
        elif args.action == "play-track":
            play_explicit_track(
                client,
                args.media_url,
                args.title,
                args.artist,
                args.album,
                args.duration,
            )
        elif args.action == "command":
            send_command(client, args.category)
        elif args.action == "play-index":
            play_cached_index(client, args.index)
        else:
            print(json.dumps({"ok": True, "service": f"ws://{HOST}:{PORT}{PATH}"}))
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (BridgeError, OSError, socket.timeout, json.JSONDecodeError) as error:
        print(f"ymc-bridge: {error}", file=sys.stderr)
        raise SystemExit(1)
