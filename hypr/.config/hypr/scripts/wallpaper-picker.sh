#!/usr/bin/env bash
# Open the wallpaper picker (Skwd-wall, through its daemon).
if command -v skwd >/dev/null 2>&1; then
    exec skwd wall toggle
fi
notify-send -a Wallpapers "Wallpaper picker not installed" "Install skwd-daemon-bin and skwd-wall-v1 (see packages/skwd-wall-v1)."
exit 1
