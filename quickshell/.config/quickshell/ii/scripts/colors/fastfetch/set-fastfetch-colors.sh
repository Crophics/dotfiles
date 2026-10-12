#!/usr/bin/env bash
# Regenerates ~/.config/fastfetch/config.jsonc and logo.txt from their
# templates, swapping in the current Material You palette (same source as
# kitty). Grays/whites in the logo art are left untouched - only the two
# accent colors (ACCENT1/ACCENT2) are theme-driven.
COLORS_JSON="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/colors.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ -f "$COLORS_JSON" ]] || exit 0

read -r ACCENT1 ACCENT1_75 ACCENT1_50 ACCENT1_30 ACCENT2 ACCENT2_75 ACCENT2_50 ACCENT2_30 <<< "$(
    jq -r '.primary, .secondary' "$COLORS_JSON" | python3 -c '
import sys
def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
def shade(c, f):
    return ";".join(str(round(ch * f)) for ch in c)
lines = [l.strip() for l in sys.stdin]
out = []
for hexcolor in lines:
    c = rgb(hexcolor)
    out += [shade(c, 1.0), shade(c, 0.75), shade(c, 0.5), shade(c, 0.3)]
print(" ".join(out))
'
)"

apply_theme() {
    sed \
        -e "s/\$ACCENT1_75/${ACCENT1_75}/g" \
        -e "s/\$ACCENT1_50/${ACCENT1_50}/g" \
        -e "s/\$ACCENT1_30/${ACCENT1_30}/g" \
        -e "s/\$ACCENT1/${ACCENT1}/g" \
        -e "s/\$ACCENT2_75/${ACCENT2_75}/g" \
        -e "s/\$ACCENT2_50/${ACCENT2_50}/g" \
        -e "s/\$ACCENT2_30/${ACCENT2_30}/g" \
        -e "s/\$ACCENT2/${ACCENT2}/g" \
        "$1" > "$2"
}

[[ -f "$SCRIPT_DIR/fastfetch-theme.jsonc" ]] && apply_theme "$SCRIPT_DIR/fastfetch-theme.jsonc" "$HOME/.config/fastfetch/config.jsonc"
[[ -f "$SCRIPT_DIR/logo-theme.txt" ]] && apply_theme "$SCRIPT_DIR/logo-theme.txt" "$HOME/.config/fastfetch/logo.txt"
