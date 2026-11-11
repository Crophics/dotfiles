#!/usr/bin/env bash
# Called by the lock screen when it has lost the keyboard while locked. Waking from suspend
# re-creates the keyboard device, and Hyprland then gives the keyboard back to the lock
# only on a click (cursor moves and focus commands don't do it). So: click once on an empty
# spot of the lock screen (top center, never on the power / restart / sleep buttons), then
# put the cursor back. wlrctl (AUR) sends the click through Wayland's virtual pointer.
command -v wlrctl >/dev/null || exit 0
read -r x y < <(hyprctl cursorpos | tr -d ,)
read -r sx sy < <(hyprctl monitors -j | python3 -c '
import json, sys
m = [x for x in json.load(sys.stdin) if x["focused"]]
if m:
    m = m[0]; print(int(m["x"] + m["width"] / m["scale"] / 2), int(m["y"] + 8))')
[ -n "$sy" ] || exit 0
hyprctl dispatch "hl.dsp.cursor.move({x=$sx, y=$sy})" >/dev/null
wlrctl pointer click left
[ -n "$y" ] && hyprctl dispatch "hl.dsp.cursor.move({x=$x, y=$y})" >/dev/null
exit 0
