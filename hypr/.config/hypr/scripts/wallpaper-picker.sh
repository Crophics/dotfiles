#!/usr/bin/env bash
# Open the wallpaper picker: Skwd-wall if it is installed, otherwise the old built-in one.
if command -v skwd-wall-v2 >/dev/null 2>&1; then
    # Skwd-wall never sets a cursor of its own, so it would inherit one hidden by the previous
    # program (kitty and Zen hide the pointer while you type). Reset it to the default first.
    hyprctl setcursor Adwaita 24 >/dev/null 2>&1
    exec skwd-wall-v2
fi
exec qs -n -p "$HOME/.config/quickshell/hyprquickpaper"
