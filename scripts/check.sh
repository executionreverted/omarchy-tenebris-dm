#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

required_files=(
    README.md AGENTS.md LICENSE docs/MARKETPLACE.md
    docs/adding-new-features.md install.sh uninstall.sh
    assets/fonts/ArgFlahm.ttf assets/fonts/Argor.txt
    assets/wallpapers/00-dungeon-gate.png
    assets/wallpapers/01-cathedral-vault.png
    media/tenebris-dashboard.png
    media/tenebris-preview.jpg media/tenebris-preview.mp4
    config/quickshell/tenebris-shell/shell.qml
    config/quickshell/tenebris-shell/settings.json
    config/quickshell/tenebris-shell/FolderPickerOverlay.qml
    config/quickshell/tenebris-shell/cava-tenebris.conf
    config/quickshell/tenebris-shell/dashboard-art.txt
    config/quickshell/tenebris-shell/folder-browser.py
    config/quickshell/tenebris-shell/place-dashboard-terminal.py
    config/quickshell/tenebris-shell/ymc-engine.py
    config/quickshell/tenebris-shell/shaders/spiderweb.frag
    config/quickshell/tenebris-shell/shaders/spiderweb.frag.qsb
    config/omarchy/themes/tenebris/colors.toml
    config/omarchy/plugins/tenebris.menu/manifest.json
    config/omarchy/plugins/tenebris.lock/manifest.json
    config/omarchy/plugins/tenebris.lock/Service.qml
    config/omarchy/plugins/tenebris.lock/LockView.qml
    config/omarchy/plugins/tenebris.lock/SealClock.qml
    config/sddm/tenebris/Main.qml
    config/sddm/tenebris/SealClock.qml
    config/sddm/tenebris/metadata.desktop
    config/sddm/tenebris/theme.conf
    config/sddm/zz-tenebris-theme.conf
    systemd/user/tenebris-ymc.service
)
for path in "${required_files[@]}"; do
    [[ -f "$path" ]] || { printf 'Missing required file: %s\n' "$path" >&2; exit 1; }
done

cmp -s config/omarchy/plugins/tenebris.lock/SealClock.qml \
    config/sddm/tenebris/SealClock.qml || {
    printf 'Lock and SDDM seal clocks have drifted apart.\n' >&2
    exit 1
}

[[ -s config/quickshell/tenebris-shell/dashboard-art.txt ]] || {
    printf 'Screensaver branding source is empty.\n' >&2
    exit 1
}

if command -v fc-scan >/dev/null; then
    font_family="$(fc-scan --format '%{family}\n' assets/fonts/ArgFlahm.ttf 2>/dev/null)"
    [[ "$font_family" == *"Argor Flahm Scaqh"* ]] || {
        printf 'Bundled Argor font has an unexpected family: %s\n' "$font_family" >&2
        exit 1
    }
fi

mapfile -t promo_videos < <(find media -maxdepth 1 -type f -name '*.mp4' -print)
if (( ${#promo_videos[@]} != 1 )); then
    printf 'Expected exactly one promotional video; found %d.\n' \
        "${#promo_videos[@]}" >&2
    exit 1
fi

bash -n install.sh uninstall.sh \
    scripts/test-installer-preflight.sh \
    scripts/test-music-player.sh \
    scripts/test-fixtures/bin/omarchy \
    scripts/test-fixtures/music/bin/playerctl \
    scripts/test-fixtures/music/bin/python3 \
    scripts/test-fixtures/music/bin/systemctl \
    scripts/test-fixtures/music/bin/ymc \
    config/quickshell/tenebris-shell/launch-dashboard-terminal.sh

scripts/test-installer-preflight.sh
scripts/test-music-player.sh

if command -v luac >/dev/null; then
    luac -p hypr/tenebris/*.lua
fi

if command -v qmllint >/dev/null; then
    qmllint config/quickshell/tenebris-shell/*.qml \
        config/omarchy/plugins/tenebris.menu/*.qml \
        config/omarchy/plugins/tenebris.lock/*.qml \
        config/sddm/tenebris/Main.qml
fi

python3 - "$repo_dir" <<'PY'
from __future__ import annotations

import ast
import configparser
import json
import re
import sys
import tomllib
from pathlib import Path

root = Path(sys.argv[1])
shell = root / "config/quickshell/tenebris-shell"
plugin = root / "config/omarchy/plugins/tenebris.menu"
lock_plugin = root / "config/omarchy/plugins/tenebris.lock"

lock_manifest = json.loads((lock_plugin / "manifest.json").read_text(encoding="utf-8"))
if lock_manifest.get("omarchy", {}).get("clonedFrom") != "omarchy.lock":
    raise SystemExit("TENEBRIS lock must remain a clone of omarchy.lock")

cava = configparser.ConfigParser()
cava.read(shell / "cava-tenebris.conf", encoding="utf-8")
cava_contract = {
    ("general", "bars"): "16",
    ("input", "method"): "pipewire",
    ("output", "method"): "raw",
    ("output", "data_format"): "ascii",
    ("output", "bar_delimiter"): "59",
    ("output", "frame_delimiter"): "10",
}
for (section, option), expected in cava_contract.items():
    actual = cava.get(section, option, fallback="")
    if actual != expected:
        raise SystemExit(
            f"Invalid Cava contract {section}.{option}: expected {expected}, got {actual or 'missing'}"
        )

installer = (root / "install.sh").read_text(encoding="utf-8")
if "config/sddm/zz-tenebris-autologin.conf" in installer:
    raise SystemExit("Installer must never deploy an SDDM autologin override")
if re.search(r"\b(?:chpasswd|passwd)\b", installer):
    raise SystemExit("Installer must never modify a user password")

dashboard = (shell / "Dashboard.qml").read_text(encoding="utf-8")
media_progress_contract = {
    "id: mediaProgressTimer": "local media progress timer",
    "interval: 250": "quarter-second media progress cadence",
    "root.syncPlayerPosition(player.position || 0)": "MPRIS position resynchronization",
    "Date.now() - root.playerPositionAnchorMs": "elapsed local media advancement",
    "id: mediaControlGuard": "asynchronous media control guard",
    "root.mediaControlPending": "media control spam prevention",
}
for needle, purpose in media_progress_contract.items():
    if needle not in dashboard:
        raise SystemExit(f"Dashboard is missing {purpose}: {needle}")

ymc_unit = (root / "systemd/user/tenebris-ymc.service").read_text(encoding="utf-8")
if "ymc-engine.py" not in ymc_unit:
    raise SystemExit("YMC service does not use the TENEBRIS repeat engine")
array_contract = {
    "core_packages": {"cava", "curl"},
    "required_commands": {"cava", "curl", "sha256sum", "fc-scan", "fc-cache"},
}
for array_name, required_entries in array_contract.items():
    match = re.search(rf"{array_name}=\((.*?)\)", installer, re.DOTALL)
    entries = set(match.group(1).split()) if match else set()
    missing_entries = sorted(required_entries - entries)
    if missing_entries:
        raise SystemExit(
            f"Installer array {array_name} is missing: {', '.join(missing_entries)}"
        )

for client in ("YMC", "cliamp"):
    if client not in installer:
        raise SystemExit(f"Installer does not expose the {client} client choice")

uninstaller = (root / "uninstall.sh").read_text(encoding="utf-8")
for client in ("YMC", "cliamp"):
    if f"Remove {client}?" not in uninstaller:
        raise SystemExit(f"Uninstaller does not ask separately about {client}")

installer_contract = {
    "assets/wallpapers/00-dungeon-gate.png": "default desktop wallpaper",
    "assets/wallpapers/01-cathedral-vault.png": "alternate desktop wallpaper",
    "config/omarchy/plugins/tenebris.lock": "TENEBRIS lock plugin",
    "config/sddm/tenebris": "optional SDDM login theme",
    "--login-screen": "SDDM install mode choice",
    "00-dungeon-gate.png": "selected default wallpaper",
    "dashboard-art.txt": "screensaver branding",
}
for needle, purpose in installer_contract.items():
    if needle not in installer:
        raise SystemExit(f"Installer is missing {purpose}: {needle}")

sddm_stage_contract = {
    "background.png",
    "ArgFlahm.ttf",
    "clock_hour_hand.png",
    "clock_minute_hand.png",
    "frame_corner.png",
    "divider_ornate.png",
    "large_sigil.png",
}
missing_sddm_assets = sorted(
    asset for asset in sddm_stage_contract if f'"$sddm_stage/{asset}"' not in installer
)
if missing_sddm_assets:
    raise SystemExit(
        "Installer does not stage SDDM assets: " + ", ".join(missing_sddm_assets)
    )

readme = (root / "README.md").read_text(encoding="utf-8")
if "https://www.youtube.com/watch?v=OBWsP2DxDxQ" not in readme:
    raise SystemExit("README is missing the YouTube showcase fallback")

for path in root.rglob("*.py"):
    ast.parse(path.read_text(encoding="utf-8"), filename=str(path))

for path in root.rglob("*.json"):
    with path.open("r", encoding="utf-8") as stream:
        json.load(stream)

for path in root.rglob("*.toml"):
    with path.open("rb") as stream:
        tomllib.load(stream)

direct_pattern = re.compile(
    r'(?:Quickshell\.shellPath|Qt\.resolvedUrl)\("([^"\n]+\.png)"\)'
)
model_pattern = re.compile(r'asset:\s*"([^"\n]+\.png)"')
workspace_pattern = re.compile(r'"(workspace_[a-z0-9_-]+\.png)"')

missing: list[str] = []
for path in shell.glob("*.qml"):
    text = path.read_text(encoding="utf-8")
    for relative in direct_pattern.findall(text):
        target = shell / relative
        if not target.is_file():
            missing.append(f"{path.relative_to(root)} -> {relative}")
    for asset in model_pattern.findall(text):
        asset_root = shell / "assets/workspaces" if asset.startswith("workspace_") else shell / "assets"
        if not (asset_root / asset).is_file():
            missing.append(f"{path.relative_to(root)} -> {asset_root.relative_to(shell)}/{asset}")
    for asset in workspace_pattern.findall(text):
        if not (shell / "assets/workspaces" / asset).is_file():
            missing.append(f"{path.relative_to(root)} -> assets/workspaces/{asset}")

for path in plugin.glob("*.qml"):
    text = path.read_text(encoding="utf-8")
    for relative in direct_pattern.findall(text):
        if not (plugin / relative).is_file():
            missing.append(f"{path.relative_to(root)} -> {relative}")

lock_asset_pattern = re.compile(r'asset\("([^"\n]+\.png)"\)')
for path in lock_plugin.glob("*.qml"):
    text = path.read_text(encoding="utf-8")
    for relative in lock_asset_pattern.findall(text):
        if not (shell / "assets" / relative).is_file():
            missing.append(
                f"{path.relative_to(root)} -> config/quickshell/tenebris-shell/assets/{relative}"
            )

if missing:
    raise SystemExit("Missing raster references:\n" + "\n".join(missing))

for forbidden in ("__pycache__", ".DS_Store"):
    matches = [str(path.relative_to(root)) for path in root.rglob(forbidden)]
    if matches:
        raise SystemExit(f"Generated files found: {', '.join(matches)}")

text_suffixes = {".md", ".qml", ".js", ".py", ".sh", ".bash", ".lua", ".toml", ".json", ".yml", ".yaml", ".ini", ".conf", ".css", ".txt", ".service", ".frag"}
for path in root.rglob("*"):
    if not path.is_file() or path.suffix.lower() not in text_suffixes:
        continue
    if path == root / "scripts/check.sh":
        continue
    text = path.read_text(encoding="utf-8")
    for forbidden in ("/home/cs", "cs.menu", "PHASEUS_MESH", "192.168.88"):
        if forbidden in text:
            raise SystemExit(f"Private or legacy reference '{forbidden}' in {path.relative_to(root)}")
PY

if command -v omarchy >/dev/null; then
    omarchy plugin validate config/omarchy/plugins/tenebris.menu >/dev/null
    omarchy plugin validate config/omarchy/plugins/tenebris.lock >/dev/null
fi

printf 'TENEBRIS validation passed.\n'
