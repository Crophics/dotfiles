#!/usr/bin/env bash
# qylock lock screen (Quickshell session lock; theme in ~/.config/qylock/theme, default clockwork/orbital).
# A lock process stays running in the background from login, so locking is instant.
#   lock.sh            lock now (starts the process first if it isn't running)
#   lock.sh --wait     same, and wait (up to 3 s) until the lock covers every screen
#   lock.sh --daemon   start the background process without locking (login autostart)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN="${XDG_RUNTIME_DIR:-/tmp}"
MARK="$RUN/qylock.locked"
QML="$DIR/lock_shell.qml"
running() { pgrep -f "[q]uickshell -p $QML" >/dev/null 2>&1; }

if [ "${1:-}" != "--run" ]; then
    if [ "${1:-}" = "--daemon" ]; then
        running || setsid -f "$0" --run >/dev/null 2>&1
        exit 0
    fi
    if running; then
        quickshell -p "$QML" ipc call lock engage >/dev/null 2>&1 || true
    else
        QYLOCK_START_LOCKED=1 setsid -f "$0" --run >/dev/null 2>&1
    fi
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

# If the lock process dies the compositor keeps the screen locked; start it again, locked.
fails=0
while :; do
    start=$(date +%s)
    (exec 9>&-; exec quickshell -p "$QML" >>"$RUN/qylock.log" 2>&1) && { rm -f "$MARK"; exit 0; }
    if [ -e "$MARK" ]; then export QYLOCK_START_LOCKED=1; else unset QYLOCK_START_LOCKED; fi   # died while locked: lock again
    [ $(( $(date +%s) - start )) -ge 3 ] && fails=0 || fails=$((fails + 1))
    [ "$fails" -ge 3 ] && sleep 2
done
