#!/usr/bin/env bash
# Fade the backlight down before the screen locks (like a phone about to sleep).
#   dim.sh dim      remember the current brightness, fade to 10% over 0.7 s
#   dim.sh restore  fade back to the remembered brightness over 0.25 s
D=${XDG_RUNTIME_DIR:-/tmp}
SAVED="$D/dim-saved"; PIDF="$D/dim.pid"
# A newer call cancels a fade still in progress.
[ -r "$PIDF" ] && kill "$(cat "$PIDF")" 2>/dev/null
echo $$ > "$PIDF"

fade() {   # fade <to> <milliseconds>; follows the clock, so slow brightnessctl calls don't stretch it
    local from to=$1 ms=$2 t0 now frac v
    qs ipc call brightness quiet $(( ms + 600 )) >/dev/null 2>&1   # no brightness popup for the fade
    from=$(brightnessctl g)
    t0=${EPOCHREALTIME/./}
    while :; do
        now=${EPOCHREALTIME/./}
        frac=$(( (now - t0) / ms ))   # 0..1000 (elapsed µs / ms)
        [ "$frac" -ge 1000 ] && break
        v=$(( from + (to - from) * frac / 1000 ))
        brightnessctl -q s "$v"
    done
    brightnessctl -q s "$to"
}

case "$1" in
dim)
    [ -e "$SAVED" ] || brightnessctl g > "$SAVED"
    max=$(brightnessctl m)
    target=$(( max / 10 ))
    cur=$(brightnessctl g)
    [ "$cur" -gt "$target" ] && fade "$target" 700
    ;;
restore)
    [ -r "$SAVED" ] || exit 0
    fade "$(cat "$SAVED")" 250
    rm -f "$SAVED"
    ;;
esac
rm -f "$PIDF"
