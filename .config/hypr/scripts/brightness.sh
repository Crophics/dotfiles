#!/usr/bin/env bash
# Brightness step for the key bind. The Fn keys only send a tap every ~260 ms while held, so the step
# grows the longer the key is held: 1x, 2x, 3x ... up to MAX_MULT x (RAMP_EVERY taps per level). Nothing runs after release.
# A pause longer than GAP, or a change of direction, starts over at 1x.
# Base step = Settings > Popups > Brightness popup.
step=5
[[ $(< "$HOME/.config/quickshell/state/brightness-state.json") =~ \"step\":[[:space:]]*([0-9]+) ]] 2>/dev/null && step=${BASH_REMATCH[1]}

GAP=700000        # µs: a longer pause means the key was released (the first repeat arrives ~520 ms after the press)
RAMP_EVERY=1      # taps per speed level
MAX_MULT=5        # biggest multiple of the base step

F=${XDG_RUNTIME_DIR:-/tmp}/brightness-hold
now=${EPOCHREALTIME/./}
last=0; dir=""; n=0
[[ -r $F ]] && read -r last dir n < "$F"
if (( now - last > GAP )) || [[ $dir != "$1" ]]; then n=0; else n=$((n + 1)); fi
echo "$now $1 $n" > "$F"

mult=$(( 1 + n / RAMP_EVERY )); (( mult > MAX_MULT )) && mult=$MAX_MULT
amount=$(( step * mult ))
[[ -n $DRY ]] && { echo "$1 ${amount}%"; exit 0; }
case "$1" in
up)   brightnessctl -q -n set "${amount}%+" ;;
down) brightnessctl -q -n set "${amount}%-" ;;
esac
"$HOME/.config/hypr/scripts/osd.sh" bri "$(brightnessctl -m | cut -d, -f4 | tr -d %)"
