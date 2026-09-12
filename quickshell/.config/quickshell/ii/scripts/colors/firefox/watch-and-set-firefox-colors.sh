#!/usr/bin/env bash
COLORS_JSON="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/colors.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

inotifywait -m -e close_write "$COLORS_JSON" | while read -r _; do
    "$SCRIPT_DIR/set-firefox-colors.sh"
done