#!/usr/bin/env bash
# Watches the generated KDE color-scheme files and re-runs the Selection
# contrast fix whenever kde-material-you-colors rewrites them. Same pattern
# as watch-and-set-firefox-colors.sh. This is the reliable trigger on this
# Hyprland setup, since kde-material-you-colors' on_change_hook is never
# reached here (it crashes earlier on an org.kde.KWin D-Bus call with no
# KWin/Plasma session running).
SCHEMES_DIR="$HOME/.local/share/color-schemes"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

inotifywait -m -e close_write "$SCHEMES_DIR" | while read -r _ _ file; do
    case "$file" in
        MaterialYou*.colors) "$SCRIPT_DIR/fix-selection-contrast.sh" ;;
    esac
done
