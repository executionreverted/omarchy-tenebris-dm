# Keep the user's interactive shell setup and pin this terminal's ceremonial title.
[[ ! -r "$HOME/.bashrc" ]] || source "$HOME/.bashrc"

# This rcfile is launched with an absolute path. Avoid `cd` here: the user's
# interactive shell hooks decorate directory changes and would contaminate a
# command substitution with display text.
__tenebris_terminal_dir="${BASH_SOURCE[0]%/*}"
__tenebris_terminal_art="$__tenebris_terminal_dir/dashboard-art.txt"

__tenebris_terminal_art_once() {
    [[ -z "${TENEBRIS_DASHBOARD_ART_SHOWN:-}" && -r "$__tenebris_terminal_art" ]] || return
    export TENEBRIS_DASHBOARD_ART_SHOWN=1
    # Let Hyprland place the native client before painting. Printing during
    # Foot's provisional startup geometry can otherwise be discarded when the
    # dashboard rule gives the window its final dimensions.
    sleep 0.24
    printf '\033[2J\033[H\033[38;2;74;77;74m'
    command cat -- "$__tenebris_terminal_art"
    printf '\033[0m\n'
}

__tenebris_terminal_title() {
    printf '\033]0;THE BLACK ARCHIVE\007'
}

PROMPT_COMMAND+=(__tenebris_terminal_art_once __tenebris_terminal_title)
