#!/usr/bin/env bash
set -Eeuo pipefail

remove_music_clients_request="ask"
remove_ymc=false
remove_cliamp=false
remove_spotify_tui=false

usage() {
    cat <<'EOF'
Usage: ./uninstall.sh [--remove-music-clients LIST]

Restores the desktop state saved by TENEBRIS. Interactive uninstalls ask about
each detected music client separately.

  --remove-music-clients LIST  Comma-separated ymc,cliamp,spotify-tui; or use
                               all or none. Login and library data are kept.
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --remove-music-clients)
            [[ $# -ge 2 ]] || { printf '%s\n' '--remove-music-clients requires a value.' >&2; exit 2; }
            remove_music_clients_request="$2"
            shift 2
            ;;
        --remove-music-clients=*)
            remove_music_clients_request="${1#*=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

state_root="$HOME/.local/state/tenebris-omarchy"
active_state="$state_root/active"
stamp="$(date +%Y%m%d-%H%M%S)"
retired_dir="$state_root/retired/$stamp"

shell_dir="$HOME/.config/quickshell/tenebris-shell"
theme_dir="$HOME/.config/omarchy/themes/tenebris"
menu_plugin_dir="$HOME/.config/omarchy/plugins/tenebris.menu"
spotify_tui_config="$HOME/.config/spotify-tui/config.yml"
cliamp_theme_file="$HOME/.config/cliamp/themes/tenebris.toml"
ymc_unit_file="$HOME/.config/systemd/user/tenebris-ymc.service"
cliamp_unit_file="$HOME/.config/systemd/user/tenebris-cliamp.service"
bar_off_file="$HOME/.local/state/omarchy/toggles/bar-off"
title_font_file="$HOME/.local/share/fonts/tenebris/ArgFlahm.ttf"

if (( EUID == 0 )); then
    printf 'Run the uninstaller as your desktop user, not as root.\n' >&2
    exit 1
fi

if [[ ! -d "$active_state" ]]; then
    printf 'No active TENEBRIS installation was found.\n'
    exit 0
fi

confirm_removal() {
    local prompt="$1" answer=""
    printf '%s' "$prompt"
    read -r answer || answer=""
    answer="${answer,,}"
    [[ "$answer" == y || "$answer" == yes ]]
}

choose_music_removals() {
    local entry normalized
    local -a requested=()

    if [[ "$remove_music_clients_request" == ask ]]; then
        if [[ ! -t 0 || ! -t 1 ]]; then
            printf 'Music clients: non-interactive uninstall, keeping all clients.\n'
            return
        fi
        printf '\nOptional music clients:\n'
        if command -v ymc >/dev/null || [[ -e "$HOME/.local/bin/youtube-music-cli" ]]; then
            confirm_removal '  Remove YMC? [y/N] ' && remove_ymc=true
        fi
        if command -v cliamp >/dev/null; then
            confirm_removal '  Remove cliamp? [y/N] ' && remove_cliamp=true
        fi
        if command -v spt >/dev/null || [[ -e "$HOME/.local/bin/spt" ]]; then
            confirm_removal '  Remove spotify-tui? [y/N] ' && remove_spotify_tui=true
        fi
        return
    fi

    normalized="${remove_music_clients_request,,}"
    case "$normalized" in
        none|"") return ;;
        all)
            remove_ymc=true
            remove_cliamp=true
            remove_spotify_tui=true
            return
            ;;
    esac
    IFS=',' read -r -a requested <<<"$normalized"
    for entry in "${requested[@]}"; do
        case "$entry" in
            ymc) remove_ymc=true ;;
            cliamp) remove_cliamp=true ;;
            spotify-tui|spotify|spt) remove_spotify_tui=true ;;
            *)
                printf 'Unknown music client: %s\n' "$entry" >&2
                return 1
                ;;
        esac
    done
}

choose_music_removals

mkdir -p "$retired_dir"

existing_pid="$(qs list --all 2>/dev/null | awk '/Process ID:/{pid=$3} /tenebris-shell/{print pid; exit}')"
[[ -z "$existing_pid" ]] || qs kill --pid "$existing_pid" >/dev/null 2>&1 || true

mapfile -t terminal_addresses < <(
    hyprctl clients -j 2>/dev/null \
        | jq -r '.[] | select(.class == "tenebris-terminal") | .address'
)
for address in "${terminal_addresses[@]}"; do
    hyprctl dispatch "hl.dsp.window.close({ window = hl.get_window('address:$address') })" \
        >/dev/null 2>&1 || true
done

if [[ -f "$active_state/managed-ymc" ]]; then
    systemctl --user disable --now tenebris-ymc.service >/dev/null 2>&1 || true
fi
if [[ -f "$active_state/managed-cliamp" ]]; then
    systemctl --user disable --now tenebris-cliamp.service >/dev/null 2>&1 || true
fi

retire_music_path() {
    local target="$1" label="$2" destination
    [[ -e "$target" || -L "$target" ]] || return
    destination="$retired_dir/music-clients/$label"
    mkdir -p "$(dirname "$destination")"
    mv "$target" "$destination"
}

remove_packaged_client() {
    local command_name="$1" expected_package="$2" command_path package
    command_path="$(command -v "$command_name" 2>/dev/null || true)"
    [[ -n "$command_path" ]] || return
    package="$(pacman -Qoq "$command_path" 2>/dev/null | head -n 1 || true)"
    if [[ "$package" == "$expected_package" ]]; then
        if ! omarchy pkg drop "$package"; then
            printf 'Could not remove %s; leaving the package installed.\n' "$package" >&2
        fi
    else
        printf 'Cannot safely remove %s from %s; remove it with its package manager.\n' \
            "$command_name" "$command_path" >&2
    fi
}

if [[ "$remove_ymc" == true ]]; then
    ymc_path="$(command -v ymc 2>/dev/null || true)"
    ymc_package=""
    [[ -z "$ymc_path" ]] || ymc_package="$(pacman -Qoq "$ymc_path" 2>/dev/null | head -n 1 || true)"
    if [[ -n "$ymc_package" ]]; then
        omarchy pkg drop "$ymc_package" || \
            printf 'Could not remove YMC package %s.\n' "$ymc_package" >&2
    elif [[ -z "$ymc_path" || "$ymc_path" == "$HOME/.local/bin/ymc" ]]; then
        retire_music_path "$HOME/.local/bin/ymc" ymc
        retire_music_path "$HOME/.local/bin/youtube-music-cli" youtube-music-cli
    else
        printf 'Cannot safely remove YMC from %s; remove it with its package manager.\n' \
            "$ymc_path" >&2
    fi
fi
if [[ "$remove_cliamp" == true ]]; then
    remove_packaged_client cliamp cliamp
fi
if [[ "$remove_spotify_tui" == true ]]; then
    spt_path="$(command -v spt 2>/dev/null || true)"
    spt_package=""
    [[ -z "$spt_path" ]] || spt_package="$(pacman -Qoq "$spt_path" 2>/dev/null | head -n 1 || true)"
    if [[ -n "$spt_package" ]]; then
        omarchy pkg drop "$spt_package" || \
            printf 'Could not remove spotify-tui package %s.\n' "$spt_package" >&2
    elif [[ -z "$spt_path" || "$spt_path" == "$HOME/.local/bin/spt" ]]; then
        retire_music_path "$HOME/.local/bin/spt" spt
    else
        printf 'Cannot safely remove spotify-tui from %s; remove it with its package manager.\n' \
            "$spt_path" >&2
    fi
fi

restore_marked_block() {
    local key="$1" target="$2" start="$3" finish="$4" temporary state
    mkdir -p "$(dirname "$target")"
    [[ -e "$target" ]] || : >"$target"
    temporary="$(mktemp)"
    awk -v start="$start" -v finish="$finish" '
        $0 == start { skip=1; next }
        $0 == finish { skip=0; next }
        !skip { print }
    ' "$target" >"$temporary"
    state="$(cat "$active_state/original/block-$key.state" 2>/dev/null || printf absent)"
    if [[ "$state" == present && -f "$active_state/original/block-$key" ]]; then
        printf '\n' >>"$temporary"
        cat "$active_state/original/block-$key" >>"$temporary"
    fi
    mv "$temporary" "$target"
}

restore_marked_block hypr-autostart "$HOME/.config/hypr/autostart.lua" \
    '-- >>> tenebris >>>' '-- <<< tenebris <<<'
restore_marked_block hypr-looknfeel "$HOME/.config/hypr/looknfeel.lua" \
    '-- >>> tenebris >>>' '-- <<< tenebris <<<'
restore_marked_block hypr-monitor "$HOME/.config/hypr/monitors.lua" \
    '-- >>> tenebris-display >>>' '-- <<< tenebris-display <<<'
restore_marked_block gtk4 "$HOME/.config/gtk-4.0/gtk.css" \
    '/* >>> tenebris >>> */' '/* <<< tenebris <<< */'
restore_marked_block gtk3 "$HOME/.config/gtk-3.0/gtk.css" \
    '/* >>> tenebris >>> */' '/* <<< tenebris <<< */'

restore_path() {
    local key="$1" target="$2" state
    state="$(cat "$active_state/original/$key.state" 2>/dev/null || printf absent)"
    if [[ -e "$target" || -L "$target" ]]; then
        mkdir -p "$(dirname "$retired_dir/$key")"
        mv "$target" "$retired_dir/$key"
    fi
    if [[ "$state" == present && -e "$active_state/original/$key" ]]; then
        mkdir -p "$(dirname "$target")"
        cp -a "$active_state/original/$key" "$target"
    fi
}

previous_theme="$(cat "$active_state/previous-theme" 2>/dev/null || true)"
current_theme="$(omarchy theme current 2>/dev/null || true)"
if [[ -n "$previous_theme" && "${current_theme,,}" == *tenebris* \
        && "${previous_theme,,}" != *tenebris* ]]; then
    omarchy theme set "$previous_theme"
fi

if [[ -e "$menu_plugin_dir" ]]; then
    omarchy plugin remove tenebris.menu --yes >/dev/null 2>&1 || true
fi

restore_path shell "$shell_dir"
restore_path theme "$theme_dir"
restore_path menu-plugin "$menu_plugin_dir"
restore_path spotify-tui "$spotify_tui_config"
restore_path cliamp-theme "$cliamp_theme_file"
restore_path ymc-unit "$ymc_unit_file"
restore_path cliamp-unit "$cliamp_unit_file"
restore_path stock-bar-state "$bar_off_file"
restore_path title-font "$title_font_file"
rmdir "$HOME/.local/share/fonts/tenebris" >/dev/null 2>&1 || true
fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true

if [[ -n "$previous_theme" && "${previous_theme,,}" == *tenebris* ]]; then
    omarchy theme set "$previous_theme"
fi

previous_background="$(cat "$active_state/previous-background" 2>/dev/null || true)"
if [[ "${previous_theme,,}" != *tenebris* && "$previous_background" == */themes/tenebris/* ]]; then
    previous_background=""
fi
if [[ -n "$previous_background" && -f "$previous_background" ]]; then
    omarchy theme bg set "$previous_background" >/dev/null 2>&1 || true
fi

previous_menu="$(cat "$active_state/previous-menu" 2>/dev/null || printf omarchy.menu)"
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
omarchy plugin enable "$previous_menu" >/dev/null 2>&1 || \
    omarchy plugin enable omarchy.menu >/dev/null 2>&1 || true

obsidian_restore="$active_state/original/obsidian-themes.tsv"
if [[ -f "$obsidian_restore" ]]; then
    while IFS=$'\t' read -r encoded_vault encoded_theme; do
        [[ -n "$encoded_vault" ]] || continue
        vault_path="$(printf '%s' "$encoded_vault" | base64 -d)"
        previous="$(printf '%s' "$encoded_theme" | base64 -d)"
        appearance="$vault_path/.obsidian/appearance.json"
        [[ -d "$vault_path/.obsidian" ]] || continue
        temporary="$(mktemp)"
        if [[ -f "$appearance" ]] && jq empty "$appearance" 2>/dev/null; then
            jq --argjson previous "$previous" \
                'if $previous == null then del(.cssTheme) else .cssTheme = $previous end' \
                "$appearance" >"$temporary"
        else
            printf '%s\n' '{}' >"$temporary"
        fi
        mv "$temporary" "$appearance"
    done <"$obsidian_restore"
fi

systemctl --user daemon-reload
if [[ "$(cat "$active_state/original/ymc-unit.enabled" 2>/dev/null || printf disabled)" == enabled ]]; then
    systemctl --user enable tenebris-ymc.service >/dev/null 2>&1 || true
fi
if [[ "$(cat "$active_state/original/ymc-unit.active" 2>/dev/null || printf inactive)" == active ]]; then
    systemctl --user start tenebris-ymc.service >/dev/null 2>&1 || true
fi
if [[ "$(cat "$active_state/original/cliamp-unit.enabled" 2>/dev/null || printf disabled)" == enabled ]]; then
    systemctl --user enable tenebris-cliamp.service >/dev/null 2>&1 || true
fi
if [[ "$(cat "$active_state/original/cliamp-unit.active" 2>/dev/null || printf inactive)" == active ]]; then
    systemctl --user start tenebris-cliamp.service >/dev/null 2>&1 || true
fi

hyprctl reload
config_errors="$(hyprctl configerrors)"
[[ -z "$config_errors" ]] || printf '%s\n' "$config_errors" >&2
omarchy restart shell

mv "$active_state" "$retired_dir/install-state"
printf 'TENEBRIS removed. Your previous desktop state was restored.\n'
printf 'Retired TENEBRIS files are recoverable at: %s\n' "$retired_dir"
printf 'Core runtime packages were left in place.\n'
if [[ "$remove_ymc" == true || "$remove_cliamp" == true \
        || "$remove_spotify_tui" == true ]]; then
    printf 'Selected music clients were removed when their install source was recognized.\n'
else
    printf 'Music clients were left in place.\n'
fi
printf 'Music login, library and credential data were preserved.\n'
