#!/usr/bin/env bash
# hypridle sleep hooks. Keeps the desktop from flashing on wake:
#   before: lock (wait until it covers the screen), then switch the screen off
#   after:  give the lock a moment to draw its first frame, then switch the screen on
D=${XDG_RUNTIME_DIR:-/tmp}
dpms() { hyprctl dispatch "hl.dsp.dpms({action=\"$1\"})" >/dev/null; }
case "$1" in
before)
    ~/.config/qylock/lock.sh --wait
    touch "$D/sleep-screen"
    dpms off
    ;;
after)
    ~/.config/qylock/lock.sh --wait   # normally a no-op: already locked
    sleep 0.5
    dpms on
    rm -f "$D/sleep-screen"
    ;;
esac
