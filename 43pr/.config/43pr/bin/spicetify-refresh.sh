#!/usr/bin/env bash
# Re-apply the generated Spotify (Spicetify) color scheme after a wallpaper change.
# Runs as a theme.py reload hook. It only updates Spotify's files; an already-open Spotify shows the new
# colors after a UI reload (Ctrl+Shift+R) or the next launch. Does nothing until `spicetify backup apply` was run.
command -v spicetify >/dev/null 2>&1 || exit 0
grep -q '^\[Backup\]' "$HOME/.config/spicetify/config-xpui.ini" 2>/dev/null || exit 0
[ -w /opt/spotify/Apps ] || exit 0
exec spicetify -q refresh >/dev/null 2>&1
