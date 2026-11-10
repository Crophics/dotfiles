#!/usr/bin/env bash
# Pick the window opacity from a rofi menu (Super+O). Same setting as Settings > Windows.
# Uses the power menu's compact theme; the current value is marked and pre-selected.
check=$'\U000F012C'
cur=$(python3 -c 'import re,sys; m=re.search(r"opacity\s*=\s*([0-9.]+)", open(sys.argv[1]).read()); print(round(float(m.group(1))*100) if m else 100)' "$HOME/.config/hypr/prefs.lua" 2>/dev/null || echo 100)
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
exec "$HOME/.config/hypr/scripts/options.py" set windows.opacity "$opacity"
