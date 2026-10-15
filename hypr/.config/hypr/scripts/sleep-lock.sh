#!/usr/bin/env bash
# Runs in the background from login. Makes the system wait before every sleep (power button,
# `systemctl suspend`, lid, idle...) until the screen is locked and the lock has drawn:
#   - holds a systemd "delay" sleep inhibitor, so logind pauses a sleep request;
#   - on the sleep request it locks (waits for the lock's first frames) and blanks the screen;
#   - then releases the inhibitor and the machine sleeps; on wake it lights the screen again
#     half a second after the lock is confirmed, then takes a new inhibitor for the next sleep.
# hypridle's own before_sleep hook does not wait for its command, which is why the desktop used to
# show on wake: the machine slept while the lock was still starting.
D=${XDG_RUNTIME_DIR:-/tmp}
LOCK="$HOME/.config/qylock/lock.sh"
EV="$D/sleep-lock.events"      # logind's PrepareForSleep signals, one line each
dpms() { hyprctl dispatch "hl.dsp.dpms({action=\"$1\"})" >/dev/null; }

if [ "${1:-}" != "--run" ]; then
    pgrep -f "[s]leep-lock.sh --run" >/dev/null || setsid -f "$0" --run >/dev/null 2>&1
    exit 0
fi

: > "$EV"
gdbus monitor --system --dest org.freedesktop.login1 --object-path /org/freedesktop/login1 >> "$EV" 2>/dev/null &
trap 'kill $! 2>/dev/null' EXIT

while :; do
    start=$(( $(wc -l < "$EV") + 1 ))
    # Hold the delay inhibitor until the next sleep request, handle it, then let go.
    systemd-inhibit --what=sleep --mode=delay --who=qylock --why="lock the screen before sleeping" \
        bash -c '
            tail -n +'"$start"' -F "'"$EV"'" 2>/dev/null | grep -m1 -q "PrepareForSleep (true"
            logger -t sleep-lock "sleep requested: locking"
            "'"$LOCK"'" --wait
            touch "'"$D"'/sleep-screen"
            hyprctl dispatch "hl.dsp.dpms({action=\"off\"})" >/dev/null
            logger -t sleep-lock "lock ready, screen off, allowing sleep"
        '
    # The machine sleeps now. Wait for the wake signal, then bring the screen back.
    tail -n +"$start" -F "$EV" 2>/dev/null | grep -m1 -q "PrepareForSleep (false"
    logger -t sleep-lock "woke"
    "$LOCK" --wait        # normally already locked
    sleep 0.5
    dpms on
    rm -f "$D/sleep-screen"
done
