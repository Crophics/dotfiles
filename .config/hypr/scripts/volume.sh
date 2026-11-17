#!/usr/bin/env bash
# Volume keys. Every separate tap counts. A held key repeats every ~40 ms, so repeats are rate-limited
# (one step per INTERVAL) and the step grows the longer the key is held: 1x, then 2x, 3x (RAMP_EVERY steps per level).
# A pause longer than GAP, or a change of direction, starts over at 1x. Capped at 100%.
step=5
INTERVAL=120000     # µs between steps while a key is held (autorepeat)
REPEAT_MAX=70000    # µs: events closer together than this are autorepeat, not separate taps
GAP=900000          # µs: a longer pause means the key was released (must exceed the 600 ms repeat delay)
RAMP_EVERY=4        # steps per speed level
MAX_MULT=3          # biggest multiple of the base step

osd() {   # show the current volume in the osd popup (red when muted)
  local v; v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
  "$HOME/.config/hypr/scripts/osd.sh" vol "$(awk '{printf "%d", $2*100+0.5}' <<<"$v")" "$([[ $v == *MUTED* ]] && echo muted)"
}
if [[ $1 == mute ]]; then wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle; osd; exit 0; fi

F=${XDG_RUNTIME_DIR:-/tmp}/volume-hold
now=${EPOCHREALTIME/./}
last=0; lastapply=0; dir=""; n=0
[[ -r $F ]] && read -r last lastapply dir n < "$F"
gap=$(( now - last ))
if (( gap > GAP )) || [[ $dir != "$1" ]]; then
  n=0; lastapply=0
elif (( gap < REPEAT_MAX )) && (( now - lastapply < INTERVAL )); then
  echo "$now $lastapply $dir $n" > "$F"; exit 0      # autorepeat arrived too soon: skip, keep the hold alive
else
  n=$(( n + 1 ))
fi
echo "$now $now $1 $n" > "$F"

mult=$(( 1 + n / RAMP_EVERY )); (( mult > MAX_MULT )) && mult=$MAX_MULT
amount=$(( step * mult ))
[[ -n $DRY ]] && { echo "$1 ${amount}%"; exit 0; }
case "$1" in
up)   wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "${amount}%+" ;;
down) wpctl set-volume @DEFAULT_AUDIO_SINK@ "${amount}%-" ;;
esac
osd
