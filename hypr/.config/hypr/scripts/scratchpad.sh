#!/usr/bin/env bash
# Special ("scratchpad") workspace helper for the Lua Hyprland config.
#   scratchpad.sh toggle           show / hide the special workspace
#   scratchpad.sh send [follow]    move the active window into it
#   scratchpad.sh return [follow]  move the active window back to the normal workspace behind it
# With "follow", focus goes along with the window.
follow=false
[[ "$2" == "follow" ]] && follow=true

case "$1" in
    toggle)
        hyprctl dispatch 'hl.dsp.workspace.toggle_special("special")'
        ;;
    send)
        hyprctl dispatch "hl.dsp.window.move({ workspace = \"special:special\", follow = $follow })"
        ;;
    return)
        ws="$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .activeWorkspace.id')"
        hyprctl dispatch "hl.dsp.window.move({ workspace = \"$ws\", follow = $follow })"
        ;;
    *)
        echo "usage: scratchpad.sh toggle|send [follow]|return [follow]" >&2
        exit 2
        ;;
esac
