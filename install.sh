#!/usr/bin/env bash
set -Eeuo pipefail

skip_packages=false
display_mode_request="ask"
display_output_request=""

usage() {
    cat <<'EOF'
Usage: ./install.sh [--skip-packages] [--display-mode MODE] [--display-output NAME]

Installs TENEBRIS for the current Omarchy user. By default, missing core
packages are installed through `omarchy pkg add`. Interactive installs offer
the connected displays' supported resolution and refresh-rate combinations.

  --skip-packages       Do not install packages; fail if a dependency is missing.
  --display-mode MODE   Use `keep` or a supported mode such as 2560x1600@240.00.
  --display-output NAME Target output for --display-mode; defaults to focused.
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --skip-packages)
            skip_packages=true
            shift
            ;;
        --display-mode)
            [[ $# -ge 2 ]] || { printf '%s\n' '--display-mode requires a value.' >&2; exit 2; }
            display_mode_request="$2"
            shift 2
            ;;
        --display-mode=*)
            display_mode_request="${1#*=}"
            shift
            ;;
        --display-output)
            [[ $# -ge 2 ]] || { printf '%s\n' '--display-output requires a value.' >&2; exit 2; }
            display_output_request="$2"
            shift 2
            ;;
        --display-output=*)
            display_output_request="${1#*=}"
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

if (( EUID == 0 )); then
    printf 'Run TENEBRIS as your desktop user, not as root.\n' >&2
    exit 1
fi

require_quattro() {
    command -v omarchy >/dev/null || {
        printf 'TENEBRIS requires Omarchy Quattro (4.x); Omarchy was not found.\n' >&2
        return 1
    }

    local version major omarchy_root missing_contract=() command_name path
    version="$(omarchy version 2>/dev/null || true)"
    if [[ "$version" =~ ^([0-9]+)\. ]]; then
        major="${BASH_REMATCH[1]}"
    else
        printf 'TENEBRIS requires Omarchy Quattro (4.x); found version: %s.\n' \
            "${version:-unknown}" >&2
        return 1
    fi

    if (( major != 4 )); then
        printf 'TENEBRIS requires Omarchy Quattro (4.x); found version: %s.\n' \
            "$version" >&2
        return 1
    fi

    for command_name in omarchy-shell omarchy-plugin-validate; do
        command -v "$command_name" >/dev/null || missing_contract+=("command:$command_name")
    done

    omarchy_root="${OMARCHY_PATH:-/usr/share/omarchy}"
    for path in \
        "$omarchy_root/shell/shell.qml" \
        "$omarchy_root/shell/services/PluginRegistry.qml" \
        "$omarchy_root/config/omarchy/shell.json"; do
        [[ -f "$path" ]] || missing_contract+=("file:$path")
    done

    if (( ${#missing_contract[@]} > 0 )); then
        printf 'Omarchy 4.x was found, but its Quattro shell contract is incomplete:\n' >&2
        printf '  %s\n' "${missing_contract[@]}" >&2
        return 1
    fi
}

# This compatibility gate must remain before package installation, state
# creation, backups, or user configuration changes.
require_quattro

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
state_root="$HOME/.local/state/tenebris-omarchy"
active_state="$state_root/active"
stamp="$(date +%Y%m%d-%H%M%S)"
replaced_dir="$state_root/replaced/$stamp"

# Workbench defaults here and remains useful even on a brand-new user account.
mkdir -p "$HOME/Projects"

shell_dir="$HOME/.config/quickshell/tenebris-shell"
theme_dir="$HOME/.config/omarchy/themes/tenebris"
menu_plugin_dir="$HOME/.config/omarchy/plugins/tenebris.menu"
gtk4_file="$HOME/.config/gtk-4.0/gtk.css"
gtk3_file="$HOME/.config/gtk-3.0/gtk.css"
spotify_tui_config="$HOME/.config/spotify-tui/config.yml"
cliamp_theme_file="$HOME/.config/cliamp/themes/tenebris.toml"
ymc_unit_file="$HOME/.config/systemd/user/tenebris-ymc.service"
cliamp_unit_file="$HOME/.config/systemd/user/tenebris-cliamp.service"
bar_off_file="$HOME/.local/state/omarchy/toggles/bar-off"
title_font_file="$HOME/.local/share/fonts/tenebris/ArgFlahm.ttf"

core_packages=(
    quickshell-git cava jq playerctl tmux xdg-terminal-exec
    noto-fonts nautilus btop xdg-user-dirs git
)
if [[ "$skip_packages" == false ]]; then
    printf 'Installing missing TENEBRIS runtime packages...\n'
    omarchy pkg add "${core_packages[@]}"
fi

required_commands=(
    qs cava flock jq hyprctl uwsm omarchy omarchy-shell python3 playerctl
    tmux xdg-terminal-exec systemctl git xdg-user-dir btop nautilus
)
missing=()
for command_name in "${required_commands[@]}"; do
    command -v "$command_name" >/dev/null || missing+=("$command_name")
done
if (( ${#missing[@]} > 0 )); then
    printf 'Missing dependencies: %s\n' "${missing[*]}" >&2
    printf 'Run without --skip-packages or install them manually.\n' >&2
    exit 1
fi

selected_display_output=""
selected_display_mode=""
selected_display_scale=""
selected_display_position=""
selected_display_transform=""

choose_display_profile() {
    local monitors_json requested output row raw_mode mode scale position transform
    local selection="1" index current_width current_height current_refresh mode_refresh
    local -a outputs=("") modes=("") scales=("") positions=("") transforms=("") labels=("")

    monitors_json="$(hyprctl monitors all -j 2>/dev/null)"
    jq -e 'type == "array" and length > 0' <<<"$monitors_json" >/dev/null || {
        printf 'Could not read connected display modes from Hyprland.\n' >&2
        return 1
    }

    if [[ "$display_mode_request" == keep ]]; then
        printf 'Display profile: keeping the existing resolution and refresh rate.\n'
        return
    fi

    if [[ "$display_mode_request" != ask ]]; then
        requested="${display_mode_request%Hz}"
        output="$display_output_request"
        if [[ -z "$output" ]]; then
            output="$(jq -r '
                (map(select(.disabled == false and .focused == true))[0]
                    // map(select(.disabled == false))[0]).name // empty
            ' <<<"$monitors_json")"
        fi
        [[ -n "$output" ]] || { printf 'No active display was found.\n' >&2; return 1; }

        row="$(jq -r --arg output "$output" --arg requested "$requested" '
            .[] | select(.disabled == false and .name == $output) as $monitor
            | $monitor.availableModes[]
            | sub("Hz$"; "")
            | select(. == $requested)
            | [$monitor.name, ., ($monitor.scale | tostring),
               (($monitor.x | tostring) + "x" + ($monitor.y | tostring)),
               ($monitor.transform | tostring)] | @tsv
        ' <<<"$monitors_json" | head -n 1)"
        [[ -n "$row" ]] || {
            printf 'Unsupported display profile: %s on %s.\n' "$requested" "$output" >&2
            printf 'Run the installer interactively to see the supported choices.\n' >&2
            return 1
        }
        IFS=$'\t' read -r selected_display_output selected_display_mode \
            selected_display_scale selected_display_position selected_display_transform <<<"$row"
        printf 'Display profile: %s at %s Hz (scale %s preserved).\n' \
            "$selected_display_output" "$selected_display_mode" "$selected_display_scale"
        return
    fi

    if [[ ! -t 0 || ! -t 1 ]]; then
        printf 'Display profile: non-interactive install, keeping existing settings.\n'
        return
    fi

    while IFS=$'\t' read -r output raw_mode scale position transform \
            current_width current_height current_refresh; do
        [[ -n "$output" && -n "$raw_mode" ]] || continue
        mode="${raw_mode%Hz}"
        outputs+=("$output")
        modes+=("$mode")
        scales+=("$scale")
        positions+=("$position")
        transforms+=("$transform")
        mode_refresh="${mode#*@}"
        if [[ "${mode%@*}" == "${current_width}x${current_height}" ]] \
                && awk -v left="$mode_refresh" -v right="$current_refresh" \
                    'BEGIN { delta = left - right; if (delta < 0) delta = -delta; exit !(delta < 0.02) }'; then
            labels+=("$output — ${mode%@*} @ ${mode#*@} Hz (current)")
        else
            labels+=("$output — ${mode%@*} @ ${mode#*@} Hz")
        fi
    done < <(jq -r '
        .[] | select(.disabled == false) as $monitor
        | $monitor.availableModes[]
        | [$monitor.name, ., ($monitor.scale | tostring),
           (($monitor.x | tostring) + "x" + ($monitor.y | tostring)),
           ($monitor.transform | tostring), ($monitor.width | tostring),
           ($monitor.height | tostring), ($monitor.refreshRate | tostring)]
        | @tsv
    ' <<<"$monitors_json")

    printf '\nDisplay profile (resolution + refresh rate):\n'
    printf '  1) Keep current settings (recommended)\n'
    for (( index = 1; index < ${#labels[@]}; index++ )); do
        printf '  %d) %s\n' "$((index + 1))" "${labels[index]}"
    done
    printf 'Choose [1]: '
    read -r selection || selection="1"
    [[ -n "$selection" ]] || selection="1"
    if [[ ! "$selection" =~ ^[0-9]+$ ]] \
            || (( selection < 1 || selection > ${#labels[@]} )); then
        printf 'Invalid display profile selection: %s\n' "$selection" >&2
        return 1
    fi
    if (( selection == 1 )); then
        printf 'Display profile: keeping the existing resolution and refresh rate.\n'
        return
    fi

    index=$((selection - 1))
    selected_display_output="${outputs[index]}"
    selected_display_mode="${modes[index]}"
    selected_display_scale="${scales[index]}"
    selected_display_position="${positions[index]}"
    selected_display_transform="${transforms[index]}"
    printf 'Display profile: %s at %s Hz (scale %s preserved).\n' \
        "$selected_display_output" "$selected_display_mode" "$selected_display_scale"
}

choose_display_profile

"$repo_dir/scripts/check.sh"

mkdir -p "$active_state/original" "$replaced_dir" \
    "$HOME/.config/quickshell" "$HOME/.config/omarchy/themes" \
    "$HOME/.config/omarchy/plugins" "$HOME/.config/hypr" \
    "$HOME/.config/systemd/user"

record_path() {
    local key="$1" target="$2"
    [[ -f "$active_state/original/$key.state" ]] && return
    if [[ -e "$target" || -L "$target" ]]; then
        printf '%s\n' present >"$active_state/original/$key.state"
        cp -a "$target" "$active_state/original/$key"
    else
        printf '%s\n' absent >"$active_state/original/$key.state"
    fi
}

record_service_state() {
    local unit="$1" key="$2"
    [[ -f "$active_state/original/$key.enabled" ]] && return
    systemctl --user is-enabled "$unit" >/dev/null 2>&1 \
        && printf '%s\n' enabled >"$active_state/original/$key.enabled" \
        || printf '%s\n' disabled >"$active_state/original/$key.enabled"
    systemctl --user is-active "$unit" >/dev/null 2>&1 \
        && printf '%s\n' active >"$active_state/original/$key.active" \
        || printf '%s\n' inactive >"$active_state/original/$key.active"
}

record_path shell "$shell_dir"
record_path theme "$theme_dir"
record_path menu-plugin "$menu_plugin_dir"
record_path spotify-tui "$spotify_tui_config"
record_path cliamp-theme "$cliamp_theme_file"
record_path ymc-unit "$ymc_unit_file"
record_path cliamp-unit "$cliamp_unit_file"
record_path stock-bar-state "$bar_off_file"
record_path title-font "$title_font_file"
record_service_state tenebris-ymc.service ymc-unit
record_service_state tenebris-cliamp.service cliamp-unit

install_optional_title_font() {
    local direct_font="${TENEBRIS_ARGOR_FONT:-}"
    local archive="${TENEBRIS_ARGOR_ARCHIVE:-$HOME/Downloads/argor_flahm_scaqh.zip}"
    local archive_entry="" extracted_font="" source_font=""

    if fc-list : family | tr ',' '\n' | grep -Fqxi 'Argor Flahm Scaqh'; then
        printf 'Optional title font already available: Argor Flahm Scaqh.\n'
        return
    fi

    if [[ -n "$direct_font" && -f "$direct_font" ]]; then
        source_font="$direct_font"
    elif [[ -f "$HOME/Downloads/ArgFlahm.ttf" ]]; then
        source_font="$HOME/Downloads/ArgFlahm.ttf"
    elif [[ -f "$archive" && -x "$(command -v bsdtar 2>/dev/null || true)" ]]; then
        archive_entry="$(bsdtar -tf "$archive" 2>/dev/null \
            | awk 'tolower($0) ~ /(^|\/)argflahm\.(ttf|otf)$/ { print; exit }')"
        if [[ -n "$archive_entry" ]]; then
            extracted_font="$(mktemp)"
            if bsdtar -xOf "$archive" "$archive_entry" >"$extracted_font" 2>/dev/null; then
                source_font="$extracted_font"
            else
                rm -f "$extracted_font"
                extracted_font=""
            fi
        fi
    fi

    if [[ -z "$source_font" ]]; then
        printf 'Optional: Argor title font not found; using the Noto fallback.\n'
        return
    fi

    if ! fc-scan --format '%{family}\n' "$source_font" 2>/dev/null \
            | grep -Fqxi 'Argor Flahm Scaqh'; then
        printf 'Optional Argor font candidate has an unexpected family; using Noto.\n' >&2
        [[ -z "$extracted_font" ]] || rm -f "$extracted_font"
        return
    fi

    install -Dm644 "$source_font" "$title_font_file"
    [[ -z "$extracted_font" ]] || rm -f "$extracted_font"
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null
    printf 'Installed the user-supplied Argor Flahm Scaqh title font.\n'
}

install_optional_title_font

if [[ ! -f "$active_state/previous-theme" ]]; then
    previous_theme="$(omarchy theme current 2>/dev/null || printf 'Tokyo Night')"
    printf '%s\n' "$previous_theme" >"$active_state/previous-theme"
fi

if [[ ! -f "$active_state/previous-menu" ]]; then
    previous_menu="$(omarchy plugin list --json 2>/dev/null \
        | jq -r '.[] | select(.enabled and (.kinds | index("menu"))) | .id' \
        | head -n 1)"
    printf '%s\n' "${previous_menu:-omarchy.menu}" >"$active_state/previous-menu"
fi

if [[ ! -f "$active_state/previous-background" ]]; then
    readlink -f "$HOME/.local/state/omarchy/current/background" \
        >"$active_state/previous-background" 2>/dev/null || : >"$active_state/previous-background"
fi

record_marked_block() {
    local key="$1" target="$2" start="$3" finish="$4" state_file block_file
    state_file="$active_state/original/block-$key.state"
    block_file="$active_state/original/block-$key"
    [[ -f "$state_file" ]] && return
    if [[ -f "$target" ]] && grep -Fqx -- "$start" "$target"; then
        printf '%s\n' present >"$state_file"
        awk -v start="$start" -v finish="$finish" '
            $0 == start { capture=1 }
            capture { print }
            capture && $0 == finish { exit }
        ' "$target" >"$block_file"
    else
        printf '%s\n' absent >"$state_file"
    fi
}

record_marked_block hypr-autostart "$HOME/.config/hypr/autostart.lua" \
    '-- >>> tenebris >>>' '-- <<< tenebris <<<'
record_marked_block hypr-looknfeel "$HOME/.config/hypr/looknfeel.lua" \
    '-- >>> tenebris >>>' '-- <<< tenebris <<<'
record_marked_block hypr-monitor "$HOME/.config/hypr/monitors.lua" \
    '-- >>> tenebris-display >>>' '-- <<< tenebris-display <<<'
record_marked_block gtk4 "$gtk4_file" \
    '/* >>> tenebris >>> */' '/* <<< tenebris <<< */'
record_marked_block gtk3 "$gtk3_file" \
    '/* >>> tenebris >>> */' '/* <<< tenebris <<< */'

obsidian_restore="$active_state/original/obsidian-themes.tsv"
if [[ ! -f "$obsidian_restore" ]]; then
    : >"$obsidian_restore"
    if [[ -f "$HOME/.config/obsidian/obsidian.json" ]]; then
        while IFS= read -r vault_path; do
            [[ -d "$vault_path/.obsidian" ]] || continue
            appearance="$vault_path/.obsidian/appearance.json"
            previous="null"
            [[ ! -f "$appearance" ]] || \
                previous="$(jq -c '.cssTheme // null' "$appearance" 2>/dev/null || printf null)"
            printf '%s\t%s\n' \
                "$(printf '%s' "$vault_path" | base64 -w 0)" \
                "$(printf '%s' "$previous" | base64 -w 0)" >>"$obsidian_restore"
        done < <(jq -r '.vaults | values[].path' "$HOME/.config/obsidian/obsidian.json" 2>/dev/null)
    fi
fi

settings_cache=""
if [[ -f "$active_state/installed" && -f "$shell_dir/settings.json" ]]; then
    settings_cache="$(mktemp)"
    cp -a "$shell_dir/settings.json" "$settings_cache"
fi

deploy_tree() {
    local source="$1" target="$2" key="$3" staged
    staged="$(mktemp -d --tmpdir="$(dirname "$target")" ".$(basename "$target").tenebris.XXXXXX")"
    cp -a "$source/." "$staged/"
    if [[ -e "$target" || -L "$target" ]]; then
        mv "$target" "$replaced_dir/$key"
    fi
    mv "$staged" "$target"
}

deploy_file() {
    local source="$1" target="$2" key="$3"
    mkdir -p "$(dirname "$target")"
    if [[ -e "$target" || -L "$target" ]]; then
        cp -a "$target" "$replaced_dir/$key"
    fi
    install -m 644 "$source" "$target"
}

omarchy plugin validate "$repo_dir/config/omarchy/plugins/tenebris.menu"
deploy_tree "$repo_dir/config/quickshell/tenebris-shell" "$shell_dir" shell
deploy_tree "$repo_dir/config/omarchy/themes/tenebris" "$theme_dir" theme
deploy_tree "$repo_dir/config/omarchy/plugins/tenebris.menu" "$menu_plugin_dir" menu-plugin

if [[ -n "$settings_cache" ]]; then
    cp -a "$settings_cache" "$shell_dir/settings.json"
    rm -f "$settings_cache"
fi
chmod 755 "$shell_dir"/*.py "$shell_dir"/*.sh

if command -v spt >/dev/null && [[ "$(spt --version 2>/dev/null || true)" == spotify-tui\ * ]]; then
    deploy_file "$repo_dir/config/spotify-tui/config.yml" "$spotify_tui_config" spotify-tui
    touch "$active_state/managed-spotify-tui"
else
    printf 'Optional: spotify-tui not found; Spotify dock integration is inactive.\n'
fi

if command -v ymc >/dev/null; then
    deploy_file "$repo_dir/systemd/user/tenebris-ymc.service" "$ymc_unit_file" ymc-unit
    touch "$active_state/managed-ymc"
else
    printf 'Optional: ymc not found; YouTube Music integration is inactive.\n'
fi

if command -v cliamp >/dev/null; then
    deploy_file "$repo_dir/systemd/user/tenebris-cliamp.service" "$cliamp_unit_file" cliamp-unit
    deploy_file "$repo_dir/config/cliamp/themes/tenebris.toml" "$cliamp_theme_file" cliamp-theme
    touch "$active_state/managed-cliamp"
else
    printf 'Optional: cliamp not found; cliamp integration is inactive.\n'
fi

replace_marked_block() {
    local target="$1" snippet="$2" start="$3" finish="$4" temporary
    mkdir -p "$(dirname "$target")"
    temporary="$(mktemp)"
    [[ -e "$target" ]] || : >"$target"
    awk -v start="$start" -v finish="$finish" '
        $0 == start { skip=1; next }
        $0 == finish { skip=0; next }
        !skip { print }
    ' "$target" >"$temporary"
    {
        cat "$temporary"
        printf '\n%s\n' "$start"
        cat "$snippet"
        printf '%s\n' "$finish"
    } >"$target"
    rm -f "$temporary"
}

remove_marked_block() {
    local target="$1" start="$2" finish="$3" temporary
    [[ -e "$target" ]] || return
    temporary="$(mktemp)"
    awk -v start="$start" -v finish="$finish" '
        $0 == start { skip=1; next }
        $0 == finish { skip=0; next }
        !skip { print }
    ' "$target" >"$temporary"
    mv "$temporary" "$target"
}

replace_marked_block "$HOME/.config/hypr/autostart.lua" \
    "$repo_dir/hypr/tenebris/autostart.snippet.lua" \
    '-- >>> tenebris >>>' '-- <<< tenebris <<<'
replace_marked_block "$HOME/.config/hypr/looknfeel.lua" \
    "$repo_dir/hypr/tenebris/looknfeel.snippet.lua" \
    '-- >>> tenebris >>>' '-- <<< tenebris <<<'
if [[ -n "$selected_display_output" ]]; then
    display_snippet="$(mktemp)"
    {
        printf '%s\n' '-- Optional display profile selected during TENEBRIS installation.'
        printf 'hl.monitor({ output = "%s", mode = "%s", position = "%s", scale = %s, transform = %s })\n' \
            "$selected_display_output" "$selected_display_mode" \
            "$selected_display_position" "$selected_display_scale" \
            "$selected_display_transform"
    } >"$display_snippet"
    replace_marked_block "$HOME/.config/hypr/monitors.lua" "$display_snippet" \
        '-- >>> tenebris-display >>>' '-- <<< tenebris-display <<<'
    rm -f "$display_snippet"
else
    remove_marked_block "$HOME/.config/hypr/monitors.lua" \
        '-- >>> tenebris-display >>>' '-- <<< tenebris-display <<<'
fi
replace_marked_block "$gtk4_file" "$repo_dir/config/gtk-4.0/tenebris.css" \
    '/* >>> tenebris >>> */' '/* <<< tenebris <<< */'
replace_marked_block "$gtk3_file" "$repo_dir/config/gtk-3.0/tenebris.css" \
    '/* >>> tenebris >>> */' '/* <<< tenebris <<< */'

mkdir -p "$(dirname "$bar_off_file")"
: >"$bar_off_file"

omarchy theme set Tenebris
omarchy-shell shell rescanPlugins >/dev/null
previous_menu="$(cat "$active_state/previous-menu" 2>/dev/null || printf omarchy.menu)"
if [[ "$previous_menu" != tenebris.menu ]]; then
    omarchy plugin disable "$previous_menu" >/dev/null 2>&1 || true
fi
omarchy plugin enable tenebris.menu >/dev/null
omarchy restart shell

if [[ -f "$HOME/.config/obsidian/obsidian.json" ]]; then
    while IFS= read -r vault_path; do
        [[ -d "$vault_path/.obsidian" ]] || continue
        appearance="$vault_path/.obsidian/appearance.json"
        temporary="$(mktemp)"
        if [[ -f "$appearance" ]] && jq empty "$appearance" 2>/dev/null; then
            jq '.cssTheme = "Omarchy"' "$appearance" >"$temporary"
        else
            printf '%s\n' '{"cssTheme":"Omarchy"}' >"$temporary"
        fi
        mv "$temporary" "$appearance"
    done < <(jq -r '.vaults | values[].path' "$HOME/.config/obsidian/obsidian.json" 2>/dev/null)
fi

omarchy theme bg set "$theme_dir/backgrounds/0-monastic-scriptorium.png"

hyprctl reload
config_errors="$(hyprctl configerrors)"
if [[ -n "$config_errors" ]]; then
    printf '%s\n' "$config_errors" >&2
    printf 'Hyprland reported errors. Run ./uninstall.sh to restore the previous state.\n' >&2
    exit 1
fi

systemctl --user daemon-reload
if [[ -f "$active_state/managed-ymc" ]] && command -v ymc >/dev/null; then
    systemctl --user enable --now tenebris-ymc.service
fi
if [[ -f "$active_state/managed-cliamp" ]] && command -v cliamp >/dev/null; then
    systemctl --user enable --now tenebris-cliamp.service
fi

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

hyprctl dispatch "hl.dsp.focus({ workspace = '1' })" >/dev/null
qs -p "$shell_dir" -d

shell_pid=""
for _attempt in 1 2 3 4 5 6; do
    shell_pid="$(qs list --all 2>/dev/null | awk '/Process ID:/{pid=$3} /tenebris-shell/{print pid; exit}')"
    [[ -z "$shell_pid" ]] || break
    sleep 0.25
done
if [[ -z "$shell_pid" ]]; then
    printf 'TENEBRIS shell did not start. Inspect: qs log -p %s\n' "$shell_dir" >&2
    exit 1
fi

touch "$active_state/installed"
printf '\nTENEBRIS installed. Workspace 1 is now the Black Archive.\n'
printf 'Restore the previous desktop at any time with: %s/uninstall.sh\n' "$repo_dir"
