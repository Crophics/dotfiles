#!/usr/bin/env bash
# Pick the window opacity from a rofi menu. Same setting as Settings > Windows.
choice=$(printf "100%%\n90%%\n80%%\n70%%\n60%%\n50%%\n40%%" | rofi -dmenu -p "")
[ -n "$choice" ] || exit 0
opacity=$(awk -v c="${choice%\%}" 'BEGIN { printf "%.2f", c / 100 }')
exec "$HOME/.config/hypr/scripts/options.py" set windows.opacity "$opacity"
