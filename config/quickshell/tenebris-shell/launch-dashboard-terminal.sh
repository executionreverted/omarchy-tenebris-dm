#!/usr/bin/env bash
set -euo pipefail

shell_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
lock_file="$runtime_dir/tenebris-dashboard-terminal.lock"

# Keep this descriptor across exec. The selected terminal process therefore
# owns the lock for its entire lifetime, making duplicate launches impossible
# even while Hyprland's toplevel model is between add/remove events.
exec 9>"$lock_file"
flock -n 9 || exit 0

if hyprctl clients -j | jq -e 'any(.[]; .class == "tenebris-terminal")' >/dev/null; then
    exit 0
fi

terminal_id="$(xdg-terminal-exec --print-id 2>/dev/null || true)"
terminal_id="${terminal_id%%:*}"
terminal_id="${terminal_id,,}"
terminal_shell=(bash --rcfile "$shell_dir/tenebris-terminal.bash" -i)

case "$terminal_id" in
    foot.desktop|org.codeberg.dnkl.foot.desktop)
        exec uwsm app -- foot \
            --config="$shell_dir/foot-dashboard.ini" \
            --app-id=tenebris-terminal \
            --title="THE BLACK ARCHIVE" \
            "${terminal_shell[@]}"
        ;;
    alacritty.desktop)
        exec uwsm app -- alacritty \
            --config-file "$shell_dir/alacritty-dashboard.toml" \
            --class tenebris-terminal \
            --title "THE BLACK ARCHIVE" \
            -e "${terminal_shell[@]}"
        ;;
    *)
        # Keep future/user-selected terminals functional through the default
        # terminal specification, even when TENEBRIS has no private profile.
        exec uwsm app -- xdg-terminal-exec \
            --app-id=tenebris-terminal \
            --title="THE BLACK ARCHIVE" \
            -- "${terminal_shell[@]}"
        ;;
esac
