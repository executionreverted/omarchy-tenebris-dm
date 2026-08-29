#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

required_files=(
    README.md AGENTS.md LICENSE docs/MARKETPLACE.md install.sh uninstall.sh
    media/tenebris-preview.jpg media/tenebris-preview.mp4
    config/quickshell/tenebris-shell/shell.qml
    config/quickshell/tenebris-shell/settings.json
    config/quickshell/tenebris-shell/FolderPickerOverlay.qml
    config/quickshell/tenebris-shell/cava-tenebris.conf
    config/quickshell/tenebris-shell/folder-browser.py
    config/quickshell/tenebris-shell/place-dashboard-terminal.py
    config/quickshell/tenebris-shell/shaders/spiderweb.frag
    config/quickshell/tenebris-shell/shaders/spiderweb.frag.qsb
    config/omarchy/themes/tenebris/colors.toml
    config/omarchy/plugins/tenebris.menu/manifest.json
)
for path in "${required_files[@]}"; do
    [[ -f "$path" ]] || { printf 'Missing required file: %s\n' "$path" >&2; exit 1; }
done

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
        config/omarchy/plugins/tenebris.menu/*.qml
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
for array_name in ("core_packages", "required_commands"):
    match = re.search(rf"{array_name}=\((.*?)\)", installer, re.DOTALL)
    entries = match.group(1).split() if match else []
    if "cava" not in entries:
        raise SystemExit(f"Installer array {array_name} does not include cava")

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
fi

printf 'TENEBRIS validation passed.\n'
