#!/usr/bin/env bash
# Lock the session with the qylock Quickshell lock screen. It shows the sign-in theme
# (~/.local/share/sddm-theme/material-you-mocha), power / restart / sleep buttons included.
# Used by Super+L, hypridle (idle + before sleep) and Hyprland's autostart (autologin).
#   lock.sh          start the lock and return at once (does nothing if already locked)
#   lock.sh --wait   also wait (up to 3 s) until the lock covers the screen and has drawn
#                    (before sleep, so waking up never shows the desktop)
#   lock.sh --instant --wait   no fade-in, ready on the first frame (suspend.sh: screen is off)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN="${XDG_RUNTIME_DIR:-/tmp}"
MARK="$RUN/qylock.locked"

if [ "${1:-}" != "--run" ]; then
    instant=""; wait=""
    for a in "$@"; do case "$a" in --instant) instant=1 ;; --wait) wait=1 ;; esac; done
    pgrep -f "quickshell -p $DIR/lock_shell.qml" >/dev/null 2>&1 || QYLOCK_INSTANT="$instant" setsid -f "$0" --run >/dev/null 2>&1
    if [ -n "$wait" ]; then
        for _ in $(seq 60); do [ -e "$MARK" ] && break; sleep 0.05; done
    fi
    exit 0
fi

# --run: the long-lived wrapper. One instance only.
exec 9>"$RUN/qylock.guard"; flock -n 9 || exit 0
rm -f "$MARK"; : > "$RUN/qylock.log"

export QML2_IMPORT_PATH="$DIR/imports:${QML2_IMPORT_PATH:-}"
export QML_XHR_ALLOW_FILE_READ=1
export QS_THEME_PATH="$HOME/.local/share/sddm-theme/material-you-mocha"
export QYLOCK_INSTANT="${QYLOCK_INSTANT:-}"   # from suspend.sh: draw the lock fully at once

# If the lock client dies, Hyprland keeps the screen locked; start it again
# (misc.allow_session_lock_restore lets the new one take over).
fails=0
while :; do
    start=$(date +%s)
    (exec 9>&-; exec quickshell -p "$DIR/lock_shell.qml" >>"$RUN/qylock.log" 2>&1) && { rm -f "$MARK"; exit 0; }
    rm -f "$MARK"; QYLOCK_INSTANT=1   # a restarted lock appears at once (the screen is locked already)
    [ $(( $(date +%s) - start )) -ge 3 ] && fails=0 || fails=$((fails + 1))
    [ "$fails" -ge 3 ] && sleep 2
done
