#!/usr/bin/env bash
# Volume keys, limited to one step per 260 ms while held so volume changes at the same speed as
# brightness (the Fn brightness keys only send a tap every ~260 ms; the volume keys would otherwise
# repeat every ~47 ms). Capped at 100%.
INTERVAL=260000   # µs between steps
D=${XDG_RUNTIME_DIR:-/tmp}
now=${EPOCHREALTIME/./}
last=0; read -r last < "$D/volume-step" 2>/dev/null
(( now - last < INTERVAL )) && exit 0
echo "$now" > "$D/volume-step"
case "$1" in
up)   exec wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ ;;
down) exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
esac
