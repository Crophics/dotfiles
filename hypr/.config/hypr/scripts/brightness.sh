#!/usr/bin/env bash
# Brightness keys: one step per call, no quickshell round trip (so held keys repeat as fast
# as the volume keys). The popup in BrightnessOsd.qml follows the backlight file.
# Step size = Settings > Popups > Brightness popup.
step=5
[[ $(< "$HOME/.config/quickshell/state/brightness-state.json") =~ \"step\":[[:space:]]*([0-9]+) ]] 2>/dev/null && step=${BASH_REMATCH[1]}
case "$1" in
up)   exec brightnessctl -q -n set "${step}%+" ;;
down) exec brightnessctl -q -n set "${step}%-" ;;
esac
