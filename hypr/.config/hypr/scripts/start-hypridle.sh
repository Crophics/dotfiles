#!/usr/bin/env bash
# Start hypridle with the settings saved from Settings > Session, or the defaults
# in hypridle.conf when nothing was saved. `restart` replaces a running instance.
conf="$HOME/.config/hypr/hypridle-user.conf"
[ -r "$conf" ] || conf="$HOME/.config/hypr/hypridle.conf"
[ "${1:-}" = "restart" ] && { pkill -x hypridle; sleep 0.5; }
pgrep -x hypridle >/dev/null || setsid -f hypridle -c "$conf" >/dev/null 2>&1
