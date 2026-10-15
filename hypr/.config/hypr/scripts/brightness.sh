#!/usr/bin/env bash
# Brightness keys, made to feel like the volume keys (one step, ~0.6 s pause, then ~21 steps/s).
# This laptop's brightness keys never autorepeat: the firmware sends a separate tap every ~260 ms.
# So: tap 1 = one step; taps 2 are ignored (volume's repeat delay); from tap 3 on a single worker
# steps every 47 ms and keeps going until no tap has arrived for 285 ms (the key was let go).
# Step size = Settings > Popups > Brightness popup.
HOLD=450000     # µs: a tap this soon after the last one means the key is held
STOP=285000     # µs without a tap = released (real taps arrive every ~260 ms)
TICK=47000      # µs between steps while held (volume repeats every ~47 ms)
step=5
[[ $(< "$HOME/.config/quickshell/state/brightness-state.json") =~ \"step\":[[:space:]]*([0-9]+) ]] 2>/dev/null && step=${BASH_REMATCH[1]}
case "$1" in up) sign=+ ;; down) sign=- ;; *) exit 1 ;; esac

D=${XDG_RUNTIME_DIR:-/tmp}
now=${EPOCHREALTIME/./}
last=0 count=0
read -r last count < "$D/brightness-tap" 2>/dev/null
(( now - last < HOLD )) && count=$((count + 1)) || count=1
echo "$now $count" > "$D/brightness-tap"
echo "$sign" > "$D/brightness-dir"

bump() { brightnessctl -q -n set "${step}%$(< "$D/brightness-dir")"; }

if (( count == 1 )); then
    bump
elif (( count >= 3 )); then
    # one worker at a time; it reads the newest tap time itself
    exec 9>"$D/brightness-worker.lock"
    flock -n 9 || exit 0
    while :; do
        read -r seen _ < "$D/brightness-tap"
        (( ${EPOCHREALTIME/./} - seen > STOP )) && break
        bump
        sleep "0.0${TICK:0:2}"
    done
fi
