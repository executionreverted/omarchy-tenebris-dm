#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_bin="$repo_dir/scripts/test-fixtures/music/bin"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

fake_home="$test_root/home"
log_file="$test_root/commands.log"
mkdir -p "$fake_home/.cache/tenebris"
printf '%s\n' '{"active":"ymc"}' >"$fake_home/.cache/tenebris/music-provider.json"
printf '%s\n' '{"queuePosition":2}' >"$fake_home/.cache/tenebris/ymc-state.json"

run_control() {
    local status="$1"
    : >"$log_file"
    HOME="$fake_home" PATH="$fixture_bin:/usr/bin:/bin" \
        TENEBRIS_FAKE_COMMAND_LOG="$log_file" \
        TENEBRIS_FAKE_PLAYER_STATUS="$status" \
        /usr/bin/python3 \
        "$repo_dir/config/quickshell/tenebris-shell/music-player.py" \
        control play-pause
}

run_control Stopped
grep -Eq 'ymc-bridge\.py play-index 2$' "$log_file" || {
    printf 'Stopped YMC did not restore its cached queue item.\n' >&2
    cat "$log_file" >&2
    exit 1
}

run_control Paused
grep -Fqx 'playerctl --player mpv play-pause' "$log_file" || {
    printf 'Paused YMC did not receive play-pause.\n' >&2
    cat "$log_file" >&2
    exit 1
}
if grep -q 'ymc-bridge.py play-index' "$log_file"; then
    printf 'Paused YMC incorrectly restarted its cached track.\n' >&2
    exit 1
fi

printf 'Music control regression tests passed.\n'
