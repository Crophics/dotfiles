#!/usr/bin/env bash
# Brightness keys. One step per tap, but this laptop's brightness keys never autorepeat like a
# held key: the firmware sends a separate tap every ~260 ms (about 4 per second), while the volume
# keys repeat every ~47 ms. So a tap that follows another within HOLD ms counts as "held" and
# does STEPS small steps spread over the gap, which gives the same speed as volume.
# Step size = Settings > Popups > Brightness popup.
HOLD=450000      # microseconds between taps that still count as a held key
STEPS=5          # steps per tap while held (~260 ms / 47 ms)
GAP=0.04         # seconds between those steps
step=5
[[ $(< "$HOME/.config/quickshell/state/brightness-state.json") =~ \"step\":[[:space:]]*([0-9]+) ]] 2>/dev/null && step=${BASH_REMATCH[1]}
case "$1" in up) sign=+ ;; down) sign=- ;; *) exit 1 ;; esac

stamp="${XDG_RUNTIME_DIR:-/tmp}/brightness-tap"
now=${EPOCHREALTIME/./}
read -r last < "$stamp" 2>/dev/null || last=0
echo "$now" > "$stamp"

if (( now - last < HOLD )); then
    for ((i = 0; i < STEPS; i++)); do
        brightnessctl -q -n set "${step}%${sign}"
        sleep "$GAP"
    done
else
    brightnessctl -q -n set "${step}%${sign}"
fi
