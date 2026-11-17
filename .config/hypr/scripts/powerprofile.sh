#!/usr/bin/env bash
# Pick the power profile from a rofi menu (Super+Ctrl+P). Same setting as Settings > Power.
# Uses the power menu's compact theme; the current profile is ticked and pre-selected.
check=$'\U000F012C'
ids=(performance balanced power-saver)
labels=("Performance" "Balanced" "Power saver")
icons=($'\U000F04C5' $'\U000F05D1' $'\U000F032A')   # speedometer, scale, leaf
# powerprofilesctl needs python-gobject (removed), so talk to the daemon over D-Bus directly.
cur=$(busctl --system get-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles \
    org.freedesktop.UPower.PowerProfiles ActiveProfile 2>/dev/null | cut -d'"' -f2)
rows=""; sel=0
for i in 0 1 2; do
    mark="   "; [ "${ids[$i]}" = "$cur" ] && { mark="$check  "; sel=$i; }
    rows+="$mark ${icons[$i]}  ${labels[$i]}"$'\n'
done
choice=$(printf '%s' "$rows" | rofi -dmenu -i -no-custom -p "" -selected-row "$sel" -format i \
    -theme "$HOME/.config/rofi/powermenu.rasi" -theme-str 'window { width: 280px; height: 184px; } listview { lines: 3; }')
[ -n "$choice" ] || exit 0
exec busctl --system set-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles \
    org.freedesktop.UPower.PowerProfiles ActiveProfile s "${ids[$choice]}"
