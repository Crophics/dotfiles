#!/usr/bin/env bash
# Night light through hyprsunset. State lives in quickshell/state/nightlight.json.
#   nightlight.sh apply              start or stop to match the saved state (also run at login)
#   nightlight.sh set <on|off> <K>   save the new state, then apply it
state="$HOME/.config/quickshell/state/nightlight.json"
mkdir -p "$(dirname "$state")"

if [ "${1:-}" = "set" ]; then
    on=false; [ "${2:-off}" = "on" ] && on=true
    printf '{"enabled":%s,"temp":%s}\n' "$on" "${3:-4500}" > "$state"
fi

enabled=$(jq -r '.enabled // false' "$state" 2>/dev/null || echo false)
temp=$(jq -r '.temp // 4500' "$state" 2>/dev/null || echo 4500)

pkill -x hyprsunset 2>/dev/null
pkill -x gammastep 2>/dev/null
if [ "$enabled" = "true" ]; then
    sleep 0.2
    setsid hyprsunset -t "$temp" >/dev/null 2>&1 &
fi
