#!/usr/bin/env bash
# Idempotent open/close of the "special" scratchpad workspace, since the
# only primitive hl.dsp.workspace.toggle_special exposes is a pure toggle.
# Usage: scratchpad-focus.sh up|down
mon="$(hyprctl activeworkspace -j | jq -r '.monitor')"
special="$(hyprctl monitors -j | jq -r --arg mon "$mon" '.[] | select(.name==$mon) | .specialWorkspace.name')"

if [[ "$1" == "up" && -z "$special" ]] || [[ "$1" == "down" && -n "$special" ]]; then
    hyprctl dispatch 'hl.dsp.workspace.toggle_special("special")'
fi
