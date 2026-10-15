#!/usr/bin/env bash
# Brightness step for the key bind (one step per call; the key's own repeat does the rest).
# Step size = Settings > Popups > Brightness popup.
step=5
[[ $(< "$HOME/.config/quickshell/state/brightness-state.json") =~ \"step\":[[:space:]]*([0-9]+) ]] 2>/dev/null && step=${BASH_REMATCH[1]}
case "$1" in
up)   exec brightnessctl -q -n set "${step}%+" ;;
down) exec brightnessctl -q -n set "${step}%-" ;;
esac
