#!/usr/bin/env bash
# hypridle sleep hooks for lid-close / system-started sleep.
# before: keep the screen blank, so the wake never shows the desktop first.
# after:  lid reopened within GRACE seconds -> just show the desktop (no lock);
#         longer -> lock first, then turn the screen on. Skipped locking when the
#         screen was already locked or the suspend was deliberate (suspend.sh
#         locks itself and touches the sleep-manual marker).
GRACE=$(jq -r '.graceSec // 60' "$HOME/.config/quickshell/state/session.json" 2>/dev/null || echo 60)   # Settings > Power
D=${XDG_RUNTIME_DIR:-/tmp}
dpms() { hyprctl dispatch "hl.dsp.dpms({action=\"$1\"})" >/dev/null; }
case "$1" in
before)
    date +%s > "$D/sleep-start"
    [ -e "$D/qylock.locked" ] && touch "$D/sleep-keep-locked" || rm -f "$D/sleep-keep-locked"
    dpms off
    ;;
after)
    start=$(cat "$D/sleep-start" 2>/dev/null || echo 0)
    if [ -e "$D/sleep-manual" ] || [ -e "$D/sleep-keep-locked" ]; then
        rm -f "$D/sleep-manual" "$D/sleep-keep-locked"
    elif [ $(( $(date +%s) - start )) -ge "$GRACE" ]; then
        ~/.config/qylock/lock.sh --wait
        sleep 0.4   # let the lock draw its first frame before the screen comes back
    fi
    dpms on
    ;;
esac
