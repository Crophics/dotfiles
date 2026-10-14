#!/usr/bin/env bash
# Open the wallpaper picker: Skwd-wall (v1, via its daemon), otherwise the old built-in one.
if command -v skwd >/dev/null 2>&1; then
    exec skwd wall toggle
fi
exec qs -n -p "$HOME/.config/quickshell/hyprquickpaper"
