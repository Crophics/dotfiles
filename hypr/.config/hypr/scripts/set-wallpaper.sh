#!/usr/bin/env bash
# Apply a wallpaper: draw it with awww, then derive the desktop colours from it (theme.py).
# Used by the wallpaper picker (Skwd-wall runs this as a post-processing command: %path%).
#   set-wallpaper.sh /path/to/image
# Transition: fade, wipe, grow, outer, wave, center, any, random (see `awww img --help`).
img="$1"
[[ -f "$img" ]] || { echo "set-wallpaper.sh: not a file: $img" >&2; exit 1; }

awww img "$img" -t random --transition-duration 1

mkdir -p "$HOME/.cache/43pr"
setsid -f python3 "$HOME/.config/43pr/bin/theme.py" wallpaper "$img" \
    >>"$HOME/.cache/43pr/theme.log" 2>&1
