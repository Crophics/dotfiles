#!/usr/bin/env bash
# hypridle sleep hooks for lid-close / system-started sleep.
# before: keep the screen blank, so the wake never shows the desktop first.
# after:  lid reopened within GRACE seconds -> just show the desktop (no lock);
#         longer -> lock first, then turn the screen on. Skipped locking when the
#         screen was already locked or the suspend was deliberate (suspend.sh
#         locks itself and touches the sleep-manual marker).
GRACE=60
D=${XDG_RUNTIME_DIR:-/tmp}
dpms() { hyprctl dispatch "hl.dsp.dpms({action=\"$1\"})" >/dev/null; }
case "$1" in
before)
    date +%s > "$D/sleep-start"
    pidof hyprlock >/dev/null && touch "$D/sleep-keep-locked" || rm -f "$D/sleep-keep-locked"
    # Locked before sleeping when the stay-away time is unknown to us would flash
    # the desktop on wake; instead lock on wake (below). Blank the screen now.
    dpms off
    ;;
after)
    start=$(cat "$D/sleep-start" 2>/dev/null || echo 0)
    if [ -e "$D/sleep-manual" ] || [ -e "$D/sleep-keep-locked" ]; then
        rm -f "$D/sleep-manual" "$D/sleep-keep-locked"
    elif [ $(( $(date +%s) - start )) -ge "$GRACE" ]; then
        pidof hyprlock >/dev/null || { hyprlock & }
        for _ in $(seq 20); do pidof hyprlock >/dev/null && break; sleep 0.1; done
        sleep 0.6   # let the lock surface draw before the screen comes back
    fi
    dpms on
    ;;
esac
