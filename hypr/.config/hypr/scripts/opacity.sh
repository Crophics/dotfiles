#!/usr/bin/env bash
# Pick the window opacity from a rofi menu. Same setting as Settings > Windows: this writes
# quickshell/state/windows.json and applies it with apply-window-prefs.sh.
state="$HOME/.config/quickshell/state/windows.json"

choice=$(printf "100%%\n90%%\n80%%\n70%%\n60%%\n50%%\n40%%" | rofi -dmenu -p "")
[ -n "$choice" ] || exit 0

opacity=$(awk -v c="${choice%\%}" 'BEGIN { printf "%.2f", c / 100 }')

mkdir -p "$(dirname "$state")"
[ -s "$state" ] || echo '{"borderSize":2,"rounding":8,"gapsIn":4}' > "$state"
tmp=$(mktemp)
jq --argjson o "$opacity" '.opacity = $o' "$state" > "$tmp" && mv "$tmp" "$state"

exec "$HOME/.config/hypr/scripts/apply-window-prefs.sh" opacity
