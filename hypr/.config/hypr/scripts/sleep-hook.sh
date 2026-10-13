#!/usr/bin/env bash
# hypridle sleep hooks. `before`: lock so the lock screen is up when waking.
# `after`: if the lid was closed and reopened within GRACE seconds, unlock again
# (no lock for a quick close/open). Skipped when the screen was already locked
# or the suspend was started on purpose (suspend.sh touches the manual marker).
GRACE=60
D=${XDG_RUNTIME_DIR:-/tmp}
case "$1" in
before)
    date +%s > "$D/sleep-start"
    if pidof hyprlock >/dev/null; then touch "$D/sleep-keep-locked"; else rm -f "$D/sleep-keep-locked"; fi
    loginctl lock-session
    sleep 1
    ;;
after)
    start=$(cat "$D/sleep-start" 2>/dev/null || echo 0)
    if [ -e "$D/sleep-manual" ] || [ -e "$D/sleep-keep-locked" ]; then
        rm -f "$D/sleep-manual" "$D/sleep-keep-locked"; exit 0
    fi
    if [ $(( $(date +%s) - start )) -lt "$GRACE" ]; then
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            pidof hyprlock >/dev/null || break
            pkill -USR1 -x hyprlock
            sleep 0.3
        done
    fi
    ;;
esac
