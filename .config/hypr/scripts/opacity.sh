#!/usr/bin/env bash
# Pick the window opacity from a rofi menu (Super+O). Rewrites the `local opacity = ...` line in
# ~/.config/hypr/rules.lua and reloads Hyprland.
# Uses the power menu's compact theme; the current value is marked and pre-selected.
check=$'\U000F012C'
rules="$HOME/.config/hypr/rules.lua"
cur=$(sed -nE 's/^local opacity = ([0-9.]+).*/\1/p' "$rules" | awk '{ printf "%d", $1 * 100 + 0.5 }')
cur=${cur:-100}
rows=""; sel=0; i=0
for v in 100 90 80 70 60 50 40; do
    mark="   "; [ "$v" = "$cur" ] && { mark="$check  "; sel=$i; }
    rows+="$mark $v%"$'\n'; i=$((i + 1))
done
choice=$(printf '%s' "$rows" | rofi -dmenu -i -no-custom -p "" -selected-row "$sel" \
    -theme "$HOME/.config/rofi/powermenu.rasi" -theme-str 'window { height: 384px; } listview { lines: 7; }')
[ -n "$choice" ] || exit 0
pct=$(grep -oE '[0-9]+%' <<<"$choice"); pct=${pct%\%}
opacity=$(awk -v c="$pct" 'BEGIN { printf "%.2f", c / 100 }')
sed -i -E "s/^local opacity = [0-9.]+/local opacity = $opacity/" "$rules"
hyprctl reload >/dev/null
