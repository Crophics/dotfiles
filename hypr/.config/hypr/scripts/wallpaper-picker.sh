#!/usr/bin/env bash
# Open the wallpaper picker: Skwd-wall if it is installed, otherwise the old built-in one.
if command -v skwd-wall-v2 >/dev/null 2>&1; then
    exec skwd-wall-v2
fi
exec qs -n -p "$HOME/.config/quickshell/hyprquickpaper"
