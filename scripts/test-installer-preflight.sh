#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mock_bin="$repo_dir/scripts/test-fixtures/bin"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

assert_untouched() {
    local fake_home="$1"
    [[ ! -e "$fake_home/.local/state/tenebris-omarchy" ]] || {
        printf 'Preflight test created TENEBRIS state in %s.\n' "$fake_home" >&2
        exit 1
    }
    [[ ! -e "$fake_home/.config" ]] || {
        printf 'Preflight test changed user config in %s.\n' "$fake_home" >&2
        exit 1
    }
}

reject_version() {
    local version="$1" fake_home="$test_root/version-${1//[^A-Za-z0-9]/-}" output
    mkdir -p "$fake_home"
    if output="$(PATH="$mock_bin:/usr/bin:/bin" HOME="$fake_home" \
            TENEBRIS_FAKE_OMARCHY_VERSION="$version" \
            "$repo_dir/install.sh" --skip-packages 2>&1)"; then
        printf 'Installer accepted unsupported Omarchy version %s.\n' "$version" >&2
        exit 1
    fi
    [[ "$output" == *"requires Omarchy Quattro (4.x)"* ]] || {
        printf 'Unexpected rejection for Omarchy %s:\n%s\n' "$version" "$output" >&2
        exit 1
    }
    assert_untouched "$fake_home"
}

reject_version "3.9.9-1"
reject_version "5.0.0-1"

missing_home="$test_root/missing"
empty_bin="$test_root/empty-bin"
mkdir -p "$missing_home" "$empty_bin"
if output="$(PATH="$empty_bin" HOME="$missing_home" \
        /usr/bin/bash "$repo_dir/install.sh" --skip-packages 2>&1)"; then
    printf 'Installer accepted a system without Omarchy.\n' >&2
    exit 1
fi
[[ "$output" == *"Omarchy was not found"* ]] || {
    printf 'Unexpected missing-Omarchy rejection:\n%s\n' "$output" >&2
    exit 1
}
assert_untouched "$missing_home"

printf 'Installer Quattro preflight tests passed.\n'
