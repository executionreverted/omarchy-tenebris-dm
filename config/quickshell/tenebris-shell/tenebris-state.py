#!/usr/bin/env python3
"""Emit one compact TENEBRIS dashboard snapshot as JSON."""

from __future__ import annotations

import configparser
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse
from urllib.request import Request, urlopen


ART_CACHE = Path.home() / ".cache" / "tenebris" / "art"
YMC_STATE_CACHE = Path.home() / ".cache" / "tenebris" / "ymc-state.json"
MUSIC_PROVIDER_CACHE = Path.home() / ".cache" / "tenebris" / "music-provider.json"
PROJECTS_STATE_CACHE = Path.home() / ".cache" / "tenebris" / "projects-state.json"
MAX_ART_BYTES = 8 * 1024 * 1024
DEMO_MODE = os.environ.get("TENEBRIS_DEMO_MODE", "").lower() in {"1", "true", "yes"}
POLL_ROLE = "default"
PREFERRED_PLAYER = ""
PROJECTS_ROOT_RAW = "~/Projects"
PROJECTS_SORT = "modified-desc"
for argument in sys.argv[1:]:
    if argument.startswith("--role="):
        requested_role = argument.partition("=")[2]
        POLL_ROLE = "".join(
            character
            for character in requested_role
            if character.isalnum() or character in "-_"
        ) or "default"
    elif argument.startswith("--projects-root="):
        PROJECTS_ROOT_RAW = argument.partition("=")[2].strip() or "~/Projects"
    elif argument.startswith("--projects-sort="):
        requested_sort = argument.partition("=")[2].strip()
        if requested_sort in {"name-asc", "name-desc", "modified-asc", "modified-desc"}:
            PROJECTS_SORT = requested_sort
    elif not PREFERRED_PLAYER:
        PREFERRED_PLAYER = argument.strip()
NETWORK_STATE_CACHE = Path.home() / ".cache" / "tenebris" / f"network-state-{POLL_ROLE}.json"


def command(args: list[str], default: str = "", timeout: float = 1.4) -> str:
    try:
        return subprocess.check_output(
            args,
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=timeout,
        ).strip()
    except (OSError, subprocess.SubprocessError):
        return default


def cpu_sample() -> tuple[int, int]:
    fields = [int(value) for value in Path("/proc/stat").read_text().splitlines()[0].split()[1:]]
    return sum(fields), fields[3] + fields[4]


def parse_network_status(raw: str) -> dict[str, str]:
    status: dict[str, str] = {}
    for line in raw.splitlines():
        key, separator, value = line.partition("\t")
        if separator and key:
            status[key] = value.strip()
    return status


def active_network_status() -> dict[str, str]:
    """Use the same active-route probe as Omarchy's network panel."""
    status = parse_network_status(
        command(["omarchy-network-status", "--verbose"], timeout=2.4)
    )
    if status.get("iface"):
        return status

    # Keep the dashboard useful if the Omarchy helper is unavailable.
    try:
        route = json.loads(command(["ip", "-j", "route", "get", "1.1.1.1"], "[]"))[0]
    except (IndexError, json.JSONDecodeError, TypeError):
        return {}

    interface = str(route.get("dev", ""))
    if not interface:
        return {}

    status = {
        "iface": interface,
        "ip": str(route.get("prefsrc", "")),
        "gateway": str(route.get("gateway", "")),
        "type": "wifi" if Path(f"/sys/class/net/{interface}/wireless").is_dir() else "ethernet",
    }
    for key, filename in (("rx_bytes", "rx_bytes"), ("tx_bytes", "tx_bytes")):
        try:
            status[key] = (Path("/sys/class/net") / interface / "statistics" / filename).read_text().strip()
        except OSError:
            pass
    return status


def network_rates(status: dict[str, str]) -> tuple[float, float]:
    """Average active-interface byte deltas between dashboard polls."""
    interface = status.get("iface", "")
    try:
        received = int(status.get("rx_bytes", "0"))
        sent = int(status.get("tx_bytes", "0"))
    except ValueError:
        received = sent = 0

    now = time.time()
    down_bps = up_bps = 0.0
    try:
        previous = json.loads(NETWORK_STATE_CACHE.read_text(encoding="utf-8"))
        elapsed = now - float(previous.get("sampleTime", 0))
        same_interface = interface and interface == str(previous.get("iface", ""))
        counters_advanced = (
            received >= int(previous.get("rxBytes", 0))
            and sent >= int(previous.get("txBytes", 0))
        )
        # The dashboard stops polling off workspace 1. Treat a long absence as
        # a fresh sample instead of presenting a stale multi-minute average.
        if same_interface and counters_advanced and 0 < elapsed <= 8:
            down_bps = (received - int(previous.get("rxBytes", 0))) / elapsed
            up_bps = (sent - int(previous.get("txBytes", 0))) / elapsed
    except (OSError, ValueError, TypeError, json.JSONDecodeError):
        pass

    try:
        NETWORK_STATE_CACHE.parent.mkdir(parents=True, exist_ok=True)
        temporary = NETWORK_STATE_CACHE.with_name(
            f"{NETWORK_STATE_CACHE.name}.{os.getpid()}.tmp"
        )
        temporary.write_text(
            json.dumps({
                "iface": interface,
                "rxBytes": received,
                "txBytes": sent,
                "sampleTime": now,
            }),
            encoding="utf-8",
        )
        os.replace(temporary, NETWORK_STATE_CACHE)
    except OSError:
        pass

    return down_bps, up_bps


def format_rate(value: float) -> str:
    if value < 1024:
        return f"{value:.0f} B/s"
    if value < 1024**2:
        return f"{value / 1024:.1f} KB/s"
    if value < 1024**3:
        return f"{value / 1024**2:.1f} MB/s"
    return f"{value / 1024**3:.2f} GB/s"


def clean_metadata(raw: str, fallback: str = "") -> str:
    value = " ".join(raw.replace("\x00", "").split())
    return value or fallback


def youtube_art_url(media_url: str) -> str:
    parsed = urlparse(media_url)
    host = parsed.netloc.lower().split(":", 1)[0]
    video_id = ""
    if host in {"youtu.be", "www.youtu.be"}:
        video_id = parsed.path.strip("/").split("/", 1)[0]
    elif host.endswith("youtube.com"):
        if parsed.path == "/watch":
            video_id = parse_qs(parsed.query).get("v", [""])[0]
        elif parsed.path.startswith(("/shorts/", "/embed/")):
            video_id = parsed.path.split("/", 2)[2]
    return f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg" if video_id else ""


def cached_art_url(raw: str) -> str:
    if not raw:
        return ""
    parsed = urlparse(raw)
    if parsed.scheme == "file":
        path = Path(unquote(parsed.path))
        return path.resolve().as_uri() if path.is_file() else ""
    if parsed.scheme not in {"http", "https"}:
        return raw

    digest = hashlib.sha256(raw.encode("utf-8", errors="replace")).hexdigest()[:24]
    candidates = list(ART_CACHE.glob(f"{digest}.*")) if ART_CACHE.is_dir() else []
    for candidate in candidates:
        if candidate.is_file() and candidate.stat().st_size > 0:
            return candidate.resolve().as_uri()

    try:
        request = Request(raw, headers={"User-Agent": "TENEBRIS/1.0 album-art cache"})
        with urlopen(request, timeout=1.8) as response:
            data = response.read(MAX_ART_BYTES + 1)
            content_type = response.headers.get_content_type()
        if not data or len(data) > MAX_ART_BYTES:
            return raw
        extension = {
            "image/jpeg": ".jpg",
            "image/png": ".png",
            "image/webp": ".webp",
            "image/gif": ".gif",
        }.get(content_type, Path(parsed.path).suffix.lower())
        if extension not in {".jpg", ".jpeg", ".png", ".webp", ".gif"}:
            extension = ".jpg"
        ART_CACHE.mkdir(parents=True, exist_ok=True)
        target = ART_CACHE / f"{digest}{extension}"
        temporary = target.with_suffix(f"{target.suffix}.tmp")
        temporary.write_bytes(data)
        temporary.replace(target)
        return target.resolve().as_uri()
    except (OSError, ValueError):
        # QML may still be able to load the remote URI directly.
        return raw


def player_source(player_id: str) -> str:
    base = player_id.split(".", 1)[0].split("_", 1)[0].upper()
    aliases = {
        "GOOGLE-CHROME": "CHROME",
        "CHROMIUM": "CHROMIUM",
        "FIREFOX": "FIREFOX",
        "SPOTIFY": "SPOTIFY",
        "MPV": "MPV",
        "VLC": "VLC",
    }
    return aliases.get(base, base or "MPRIS")


def ymc_cached_track() -> dict:
    try:
        state = json.loads(YMC_STATE_CACHE.read_text(encoding="utf-8"))
        track = state.get("currentTrack")
        return track if isinstance(track, dict) else {}
    except (OSError, json.JSONDecodeError, AttributeError):
        return {}


def ymc_cached_player() -> dict:
    track = ymc_cached_track()
    video_id = str(track.get("videoId", ""))
    if not video_id:
        return {}
    artists = track.get("artists", [])
    artist = ", ".join(
        str(item.get("name", "")).strip()
        for item in artists
        if isinstance(item, dict) and str(item.get("name", "")).strip()
    )
    album_value = track.get("album")
    album = clean_metadata(str(album_value.get("name", ""))) if isinstance(album_value, dict) else ""
    try:
        duration = max(0, float(track.get("duration", 0)))
    except (TypeError, ValueError):
        duration = 0
    media_url = f"https://www.youtube.com/watch?v={video_id}"
    try:
        state = json.loads(YMC_STATE_CACHE.read_text(encoding="utf-8"))
        repeat = str(state.get("repeat", "off")).lower()
    except (OSError, json.JSONDecodeError, AttributeError):
        repeat = "off"
    return {
        "status": "PAUSED",
        "artist": artist or "UNKNOWN ARTIST",
        "title": clean_metadata(str(track.get("title", "")), video_id),
        "album": album,
        "source": "YMC",
        "id": "ymc",
        "url": media_url,
        "videoId": video_id,
        "artUrl": cached_art_url(f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg"),
        "position": 0,
        "length": round(duration),
        "repeat": repeat if repeat in {"off", "all", "one"} else "off",
    }


def active_music_provider() -> tuple[str, dict[str, bool]]:
    available = {
        "ymc": shutil.which("ymc") is not None,
        "cliamp": shutil.which("cliamp") is not None,
    }
    try:
        provider = str(json.loads(MUSIC_PROVIDER_CACHE.read_text(encoding="utf-8")).get("active", ""))
    except (OSError, json.JSONDecodeError, AttributeError):
        provider = ""
    if not available.get(provider, False):
        provider = next((name for name in ("ymc", "cliamp") if available[name]), "")
    return provider, available


def cliamp_player() -> dict:
    try:
        status = json.loads(command(["cliamp", "status", "--json"], "{}", timeout=1.0))
    except json.JSONDecodeError:
        status = {}
    track = status.get("track") if isinstance(status.get("track"), dict) else {}
    state = clean_metadata(str(status.get("state", "stopped")), "stopped").upper()
    source_path = clean_metadata(str(track.get("path", "")))
    raw_art = clean_metadata(str(track.get("album_art_url", "")))
    if raw_art and not urlparse(raw_art).scheme:
        art_path = Path(raw_art).expanduser()
        raw_art = art_path.resolve().as_uri() if art_path.is_file() else raw_art
    try:
        position = max(0, float(status.get("position", 0)))
    except (TypeError, ValueError):
        position = 0
    try:
        duration = max(0, float(status.get("duration", track.get("duration_secs", 0))))
    except (TypeError, ValueError):
        duration = 0
    repeat = str(status.get("repeat", "off")).lower()
    return {
        "status": state if state in {"PLAYING", "PAUSED", "STOPPED"} else "SILENT",
        "artist": clean_metadata(str(track.get("artist", "")), "UNKNOWN ARTIST"),
        "title": clean_metadata(str(track.get("title", "")), "THE ARCHIVE RESTS"),
        "album": clean_metadata(str(track.get("album", ""))),
        "source": "CLIAMP",
        "id": "cliamp",
        "url": source_path,
        "videoId": "",
        "artUrl": cached_art_url(raw_art or youtube_art_url(source_path)),
        "position": round(position),
        "length": round(duration),
        "repeat": repeat if repeat in {"off", "all", "one"} else "off",
    }


def github_remote_url(raw: str) -> str:
    value = raw.strip()
    if value.startswith("git@github.com:"):
        repository = value.split(":", 1)[1]
    else:
        parsed = urlparse(value)
        if (parsed.hostname or "").lower() != "github.com":
            return ""
        repository = parsed.path
    repository = repository.strip("/")
    if repository.endswith(".git"):
        repository = repository[:-4]
    if repository.count("/") < 1:
        return ""
    return f"https://github.com/{repository}"


def project_git_directory(path: Path) -> Path | None:
    marker = path / ".git"
    if marker.is_dir():
        return marker
    if not marker.is_file():
        return None
    try:
        line = marker.read_text(encoding="utf-8", errors="replace").strip()
        prefix, separator, raw_path = line.partition(":")
        if separator and prefix.strip().lower() == "gitdir":
            candidate = Path(raw_path.strip())
            if not candidate.is_absolute():
                candidate = path / candidate
            resolved = candidate.resolve()
            return resolved if resolved.is_dir() else None
    except OSError:
        pass
    return None


def project_git_metadata(path: Path) -> tuple[str, bool, str]:
    git_directory = project_git_directory(path)
    if git_directory is None:
        return "archive", False, ""

    branch = "detached"
    try:
        head = (git_directory / "HEAD").read_text(encoding="utf-8", errors="replace").strip()
        if head.startswith("ref:"):
            branch = head.partition(":")[2].strip().rsplit("/", 1)[-1] or "archive"
        elif head:
            branch = head[:8]
    except OSError:
        pass

    origin = ""
    parser = configparser.RawConfigParser()
    try:
        parser.read(git_directory / "config", encoding="utf-8")
        origin = parser.get('remote "origin"', "url", fallback="")
    except (OSError, configparser.Error):
        pass
    return branch, True, github_remote_url(origin)


def selected_projects_root() -> Path:
    fallback = Path.home() / "Projects"
    try:
        candidate = Path(PROJECTS_ROOT_RAW).expanduser().resolve()
        candidate.relative_to(Path.home().resolve())
        return candidate if candidate.is_dir() else fallback
    except (OSError, ValueError):
        return fallback


def project_catalog(root: Path) -> tuple[list[dict], str]:
    try:
        root_mtime = root.stat().st_mtime_ns
    except OSError:
        return [], "empty"

    now = time.time()
    try:
        cached = json.loads(PROJECTS_STATE_CACHE.read_text(encoding="utf-8"))
        if (
            cached.get("root") == str(root)
            and cached.get("sort") == PROJECTS_SORT
            and int(cached.get("rootMtime", -1)) == root_mtime
            and now - float(cached.get("generatedAt", 0)) < 30
            and isinstance(cached.get("projects"), list)
        ):
            return cached["projects"], str(cached.get("revision", "cached"))
    except (OSError, ValueError, TypeError, json.JSONDecodeError):
        pass

    candidates: list[tuple[Path, int]] = []
    try:
        for item in root.iterdir():
            if item.name.startswith(".") or not item.is_dir():
                continue
            try:
                modified = item.stat().st_mtime_ns
            except OSError:
                modified = 0
            candidates.append((item, modified))
    except OSError:
        return [], "empty"

    if PROJECTS_SORT.startswith("name-"):
        candidates.sort(
            key=lambda item: item[0].name.casefold(),
            reverse=PROJECTS_SORT == "name-desc",
        )
    else:
        candidates.sort(
            key=lambda item: (item[1], item[0].name.casefold()),
            reverse=PROJECTS_SORT == "modified-desc",
        )

    projects: list[dict] = []
    for path, modified in candidates:
        branch, is_git, github_url = project_git_metadata(path)
        projects.append({
            "name": path.name,
            "path": str(path),
            "branch": branch,
            "isGit": is_git,
            "githubUrl": github_url,
            "modified": modified,
        })

    payload = json.dumps(projects, ensure_ascii=False, sort_keys=True)
    revision = hashlib.sha256(
        f"{root}\0{PROJECTS_SORT}\0{payload}".encode("utf-8", errors="replace")
    ).hexdigest()[:16]
    try:
        PROJECTS_STATE_CACHE.parent.mkdir(parents=True, exist_ok=True)
        temporary = PROJECTS_STATE_CACHE.with_name(
            f"{PROJECTS_STATE_CACHE.name}.{os.getpid()}.tmp"
        )
        temporary.write_text(json.dumps({
            "root": str(root),
            "sort": PROJECTS_SORT,
            "rootMtime": root_mtime,
            "generatedAt": now,
            "revision": revision,
            "projects": projects,
        }), encoding="utf-8")
        os.replace(temporary, PROJECTS_STATE_CACHE)
    except OSError:
        pass
    return projects, revision


total_a, idle_a = cpu_sample()
time.sleep(0.32)
total_b, idle_b = cpu_sample()
cpu = 100 * (1 - (idle_b - idle_a) / max(1, total_b - total_a))

network_status = active_network_status()
down_bps, up_bps = network_rates(network_status)

memory: dict[str, int] = {}
for line in Path("/proc/meminfo").read_text().splitlines():
    key, value = line.split(":", 1)
    memory[key] = int(value.split()[0])
ram = 100 * (memory["MemTotal"] - memory["MemAvailable"]) / memory["MemTotal"]
ram_used = (memory["MemTotal"] - memory["MemAvailable"]) / 1024**2
ram_total = memory["MemTotal"] / 1024**2

disk = shutil.disk_usage(Path.home())
disk_percent = 100 * disk.used / max(1, disk.total)

cpu_temp = 0
for sensor in Path("/sys/class/hwmon").glob("hwmon*/temp*_input"):
    try:
        value = int(sensor.read_text()) // 1000
        if 20 <= value <= 110:
            cpu_temp = max(cpu_temp, value)
    except (OSError, ValueError):
        pass

battery = 0
battery_status = "AC"
for supply in sorted(Path("/sys/class/power_supply").glob("BAT*")):
    try:
        battery = int((supply / "capacity").read_text())
        battery_status = (supply / "status").read_text().strip().upper()
        break
    except (OSError, ValueError):
        continue

network_interface = network_status.get("iface", "")
network_type = network_status.get("type", "")
ip_address = network_status.get("ip", "") or "SEALED"
if network_type == "wifi":
    network_kind = "WI-FI"
    network_name = network_status.get("ssid", "") or network_interface
elif network_type == "ethernet":
    network_kind = "ETHERNET"
    network_name = network_interface
else:
    network_kind = "DISCONNECTED"
    network_name = "NO ACTIVE LINK"

signal_dbm = network_status.get("signal_dbm", "")
network_signal = f"{signal_dbm} dBm" if signal_dbm else "--"
network_band = ""
try:
    frequency = float(network_status.get("freq", "0"))
    if frequency >= 5925:
        network_band = "6 GHz"
    elif frequency >= 4900:
        network_band = "5 GHz"
    elif frequency >= 2300:
        network_band = "2.4 GHz"
except ValueError:
    pass

if DEMO_MODE:
    network_status = {
        **network_status,
        "bitrate": "866 MBit/s",
        "gateway": "10.0.0.1",
    }
    network_interface = "wlan0"
    network_kind = "WI-FI"
    network_name = "ARCHIVE_LINK"
    ip_address = "10.0.0.24"
    network_signal = "-42 dBm"
    network_band = "5 GHz"

music_provider, music_available = active_music_provider()
player = {
    "status": "SILENT",
    "artist": "NO CANTICLE",
    "title": "THE ARCHIVE RESTS",
    "album": "",
    "source": "",
    "id": "",
    "artUrl": "",
    "position": 0,
    "length": 0,
    "repeat": "off",
}
if music_provider == "cliamp":
    player = cliamp_player()
else:
    players = command(["playerctl", "-l"]).splitlines()
    selected = ""
    statuses = {
        candidate: command(["playerctl", "--player", candidate, "status"], "Stopped")
        for candidate in players
    }
    preferred_player = "mpv" if music_provider == "ymc" else PREFERRED_PLAYER
    if players:
        if preferred_player:
            selected = next(
                (
                    candidate for candidate in players
                    if candidate == preferred_player or candidate.startswith(f"{preferred_player}.")
                ),
                "",
            )
        else:
            selected = next(
                (candidate for candidate in players if statuses[candidate] == "Playing"),
                next((candidate for candidate in players if statuses[candidate] == "Paused"), players[0]),
            )

    if selected:
        status = statuses[selected].upper()
        artist = clean_metadata(
            command(["playerctl", "--player", selected, "metadata", "xesam:artist"]),
            "UNKNOWN ARTIST",
        )
        title = clean_metadata(
            command(["playerctl", "--player", selected, "metadata", "xesam:title"]),
            "UNTITLED",
        )
        album = clean_metadata(command(["playerctl", "--player", selected, "metadata", "xesam:album"]))
        media_url = command(["playerctl", "--player", selected, "metadata", "xesam:url"])
        raw_art = command(["playerctl", "--player", selected, "metadata", "mpris:artUrl"])
        cached_track = ymc_cached_track() if music_provider == "ymc" else {}
        cached_video_id = str(cached_track.get("videoId", ""))
        if cached_video_id:
            title = clean_metadata(str(cached_track.get("title", "")), title)
            artists = cached_track.get("artists", [])
            cached_artists = ", ".join(
                str(item.get("name", "")).strip()
                for item in artists
                if isinstance(item, dict) and str(item.get("name", "")).strip()
            )
            artist = cached_artists or artist
            cached_album = cached_track.get("album")
            if isinstance(cached_album, dict):
                album = clean_metadata(str(cached_album.get("name", "")), album)
            media_url = f"https://www.youtube.com/watch?v={cached_video_id}"
            raw_art = f"https://i.ytimg.com/vi/{cached_video_id}/hqdefault.jpg"
        art = cached_art_url(raw_art or youtube_art_url(media_url))
        position_raw = command(["playerctl", "--player", selected, "position"], "0")
        length_raw = command(["playerctl", "--player", selected, "metadata", "mpris:length"], "0")
        try:
            position = float(position_raw)
        except ValueError:
            position = 0
        try:
            length = int(length_raw) / 1_000_000
        except ValueError:
            length = 0
        if length <= 0 and cached_track:
            try:
                length = float(cached_track.get("duration", 0))
            except (TypeError, ValueError):
                length = 0
        player = {
            "status": status,
            "artist": artist,
            "title": title,
            "album": album,
            "source": player_source(selected),
            "id": selected,
            "url": media_url,
            "videoId": cached_video_id,
            "artUrl": art,
            "position": round(position),
            "length": round(length),
            "repeat": "off",
        }
        if music_provider == "ymc":
            try:
                ymc_state = json.loads(YMC_STATE_CACHE.read_text(encoding="utf-8"))
                repeat = str(ymc_state.get("repeat", "off")).lower()
                player["repeat"] = repeat if repeat in {"off", "all", "one"} else "off"
            except (OSError, json.JSONDecodeError, AttributeError):
                pass
    elif music_provider == "ymc":
        player = ymc_cached_player() or player

projects_root = selected_projects_root()
if DEMO_MODE:
    projects = [
        {
            "name": name,
            "path": str(projects_root),
            "branch": branch,
            "isGit": True,
            "githubUrl": "",
        }
        for name, branch in (
            ("SCRIPTORIUM", "main"),
            ("RELIQUARY", "dev"),
            ("WAYFARER", "main"),
        )
    ]
    projects_revision = "demo"
else:
    projects, projects_revision = project_catalog(projects_root)

clients = []
active_workspace = 1
try:
    clients = json.loads(command(["hyprctl", "clients", "-j"], "[]"))
    active_workspace = int(json.loads(command(["hyprctl", "activeworkspace", "-j"], "{}") or "{}").get("id", 1))
except (json.JSONDecodeError, TypeError, ValueError):
    pass

workspaces = []
for workspace_id in range(1, 11):
    matches = [client for client in clients if client.get("workspace", {}).get("id") == workspace_id]
    workspaces.append({
        "id": workspace_id,
        "count": len(matches),
        "active": workspace_id == active_workspace,
        "apps": [str(client.get("class", "")).upper()[:14] for client in matches[:2]],
    })

terminal_client = next((client for client in clients if client.get("class") == "tenebris-terminal"), None)
terminal_present = terminal_client is not None
terminal_workspace = ""
if terminal_client:
    terminal_workspace = str(terminal_client.get("workspace", {}).get("name", ""))
ymc_client = next((client for client in clients if client.get("class") == "tenebris-ymc"), None)
ymc_workspace = str(ymc_client.get("workspace", {}).get("name", "")) if ymc_client else ""
ymc_visible = bool(ymc_client and not ymc_workspace.startswith("special:"))
cliamp_client = next((client for client in clients if client.get("class") == "tenebris-cliamp"), None)
cliamp_workspace = str(cliamp_client.get("workspace", {}).get("name", "")) if cliamp_client else ""
cliamp_visible = bool(cliamp_client and not cliamp_workspace.startswith("special:"))
dashboard_occupied = any(
    client.get("workspace", {}).get("id") == 1
    and client.get("class") != "tenebris-terminal"
    for client in clients
)

uptime_seconds = int(float(Path("/proc/uptime").read_text().split()[0]))
uptime_days, uptime_remainder = divmod(uptime_seconds, 86400)
uptime_hours = uptime_remainder // 3600
uptime = f"{uptime_days}d {uptime_hours}h" if uptime_days else f"{uptime_hours}h {(uptime_remainder % 3600) // 60}m"

print(json.dumps({
    "cpu": round(cpu),
    "cpuTemp": cpu_temp,
    "ram": round(ram),
    "ramText": f"{ram_used:.1f}/{ram_total:.1f}G",
    "disk": round(disk_percent),
    "diskText": f"{disk.used / 1024**3:.0f}/{disk.total / 1024**3:.0f}G",
    "downText": format_rate(down_bps),
    "upText": format_rate(up_bps),
    "ip": ip_address,
    "network": {
        "name": network_name,
        "kind": network_kind,
        "iface": network_interface,
        "signal": network_signal,
        "band": network_band,
        "bitrate": network_status.get("bitrate", ""),
        "gateway": network_status.get("gateway", ""),
    },
    "battery": battery,
    "batteryStatus": battery_status,
    "uptime": uptime,
    "player": player,
    "projects": projects,
    "projectsRoot": str(projects_root),
    "projectsRevision": projects_revision,
    "workspaces": workspaces,
    "terminalPresent": terminal_present,
    "terminalWorkspace": terminal_workspace,
    "dashboardOccupied": dashboard_occupied,
    "ymcVisible": ymc_visible,
    "music": {
        "active": music_provider,
        "ymcAvailable": music_available["ymc"],
        "cliampAvailable": music_available["cliamp"],
        "ymcVisible": ymc_visible,
        "cliampVisible": cliamp_visible,
    },
    "capabilities": {
        "code": shutil.which("code") is not None,
        "playerctl": shutil.which("playerctl") is not None,
    },
    "host": "TENEBRIS" if DEMO_MODE else os.uname().nodename,
}, ensure_ascii=False))
