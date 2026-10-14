#!/usr/bin/env bash
# Lock the session with the qylock Quickshell lock (theme in ~/.config/qylock/theme,
# default clockwork/orbital). Does nothing if already locked.
#   lock.sh          start the lock and return at once
#   lock.sh --wait   also wait (up to 3 s) until it covers every screen
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN="${XDG_RUNTIME_DIR:-/tmp}"
MARK="$RUN/qylock.locked"

if [ "${1:-}" != "--run" ]; then
    pgrep -f "quickshell -p $DIR/lock_shell.qml" >/dev/null 2>&1 || setsid -f "$0" --run >/dev/null 2>&1
    if [ "${1:-}" = "--wait" ]; then
        for _ in $(seq 60); do [ -e "$MARK" ] && break; sleep 0.05; done
    fi
    exit 0
fi

# --run: the long-lived wrapper. One instance only.
exec 9>"$RUN/qylock.guard"; flock -n 9 || exit 0
rm -f "$MARK"; : > "$RUN/qylock.log"

export QML2_IMPORT_PATH="$DIR/imports:${QML2_IMPORT_PATH:-}"
export QML_XHR_ALLOW_FILE_READ=1
export XDG_SESSION_TYPE=wayland
export QS_THEME="$(cat "$HOME/.config/qylock/theme" 2>/dev/null || echo clockwork/orbital)"
export QS_THEME_PATH="$DIR/themes/$QS_THEME"
if [ ! -f "$QS_THEME_PATH/Main.qml" ]; then
    echo "qylock: theme '$QS_THEME' missing, using clockwork/orbital" >&2
    export QS_THEME=clockwork/orbital QS_THEME_PATH="$DIR/themes/clockwork/orbital"
fi

# If the lock client dies the compositor keeps the screen locked; start it again.
fails=0
while :; do
    start=$(date +%s)
    (exec 9>&-; exec quickshell -p "$DIR/lock_shell.qml" >>"$RUN/qylock.log" 2>&1) && { rm -f "$MARK"; exit 0; }
    rm -f "$MARK"
    [ $(( $(date +%s) - start )) -ge 3 ] && fails=0 || fails=$((fails + 1))
    [ "$fails" -ge 3 ] && sleep 2
done
