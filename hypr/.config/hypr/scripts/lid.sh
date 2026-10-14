#!/usr/bin/env bash
# Lid handling (logind's own lid action is blocked by an inhibitor, see lid-inhibit.sh).
#   close: screen off. After the skip-lock time (Settings > Power) with the lid still
#          closed: lock, then suspend. 0 = suspend right away.
#   open:  cancel the countdown and light the screen. If it already suspended, the
#          screen was locked first, so you get the lock screen.
D=${XDG_RUNTIME_DIR:-/tmp}; PIDF="$D/lid-timer.pid"
GRACE=$(jq -r '.graceSec // 60' "$HOME/.config/quickshell/state/session.json" 2>/dev/null || echo 60)
dpms() { hyprctl dispatch "hl.dsp.dpms({action=\"$1\"})" >/dev/null; }
stop_timer() { [ -r "$PIDF" ] && kill "$(cat "$PIDF")" 2>/dev/null; rm -f "$PIDF"; }

case "$1" in
close)
    # With an external screen attached the laptop keeps running, as before.
    [ "$(hyprctl monitors -j | jq length)" -gt 1 ] && exit 0
    stop_timer
    dpms off
    setsid -f bash -c '
        echo $$ > "'"$PIDF"'"
        sleep '"$GRACE"'
        rm -f "'"$PIDF"'"
        exec ~/.config/hypr/scripts/suspend.sh' >/dev/null 2>&1
    ;;
open)
    stop_timer
    dpms on
    ;;
esac
