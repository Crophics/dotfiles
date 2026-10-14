#!/usr/bin/env bash
# Export or import the Settings app's saved choices (quickshell/state).
#   settings-backup.sh export [file]   default ~/Documents/settings-backup-<date>.tar.gz
#   settings-backup.sh import <file>   current settings are saved to state.bak-<time>.tar.gz first
set -euo pipefail
cfg="$HOME/.config"
state="$cfg/quickshell/state"

case "${1:-}" in
export)
    out="${2:-$HOME/Documents/settings-backup-$(date +%F).tar.gz}"
    mkdir -p "$(dirname "$out")"
    tar czf "$out" -C "$cfg/quickshell" --exclude='*.tmp' --exclude='display.prev.json' state
    echo "$out"
    ;;
import)
    file="${2:?file}"
    [ -r "$file" ] || { echo "Can't read $file" >&2; exit 1; }
    # Only plain files under state/ are accepted.
    while IFS= read -r entry; do
        case "$entry" in state/*|state) ;; *) echo "Not a settings backup (unexpected path: $entry)" >&2; exit 1 ;; esac
        case "$entry" in *..*) echo "Not a settings backup" >&2; exit 1 ;; esac
    done < <(tar tzf "$file")
    tar czf "$cfg/quickshell/state.bak-$(date +%H%M%S).tar.gz" -C "$cfg/quickshell" state 2>/dev/null || true
    tar xzf "$file" -C "$cfg/quickshell" --no-same-owner state
    # Rebuild everything generated from those files.
    "$cfg/hypr/scripts/options.py" build
    "$cfg/hypr/scripts/startup.py"
    "$cfg/hypr/scripts/apply-keybinds.sh" >/dev/null 2>&1 || true
    "$cfg/hypr/scripts/apply-session-prefs.sh" >/dev/null 2>&1 || true
    "$cfg/hypr/scripts/nightlight.py" apply >/dev/null 2>&1 || true
    hyprctl reload >/dev/null
    echo done
    ;;
*) sed -n '2,4p' "$0"; exit 2 ;;
esac
