#!/usr/bin/env bash
# Contrast fix for kde-material-you-colors' [Colors:Selection]. Invoked two
# ways: as its on_change_hook (~/.config/kde-material-you-colors/config.conf)
# on setups where that step is reached, and by watch-and-fix-selection-contrast.sh
# (inotify on the .colors files) as the reliable path on this Hyprland setup,
# where kde-material-you-colors crashes on an org.kde.KWin D-Bus call before
# ever reaching on_change_hook (no KWin/Plasma session here). Same flock
# pattern as set-firefox-colors.sh to avoid concurrent-run corruption when
# multiple .colors files are written back-to-back.
exec 200>/tmp/fix-selection-contrast.lock
flock -n 200 || exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/fix-selection-contrast.py"

mode=$(grep -m1 '^ColorScheme=' "$HOME/.config/kdeglobals" 2>/dev/null | cut -d= -f2)
case "$mode" in
    MaterialYouLight) base="$HOME/.local/share/color-schemes/MaterialYouLight" ;;
    MaterialYouDark)  base="$HOME/.local/share/color-schemes/MaterialYouDark" ;;
    *) exit 0 ;;
esac

# plasma-apply-colorscheme no-ops when pointed at the same file it just
# applied, so bounce through the "2" copy first -- the same reload trick
# kde-material-you-colors itself uses in plasma_utils.apply_color_schemes.
plasma-apply-colorscheme "${base}2.colors" >/dev/null 2>&1
plasma-apply-colorscheme "${base}.colors" >/dev/null 2>&1
