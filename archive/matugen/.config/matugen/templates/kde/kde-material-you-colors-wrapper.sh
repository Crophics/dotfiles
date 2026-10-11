#!/usr/bin/env bash
# Wrapper for kde-material-you-colors, called by
# ~/.config/quickshell/ii/scripts/colors/switchwall.sh with
# --scheme-variant <matugen-style scheme name>. This isn't a Plasma session,
# so we bypass its Plasma-desktop wallpaper detection entirely.
#
# Originally handed it the wallpaper image directly via --file, letting it
# derive its own seed color independently. That meant kde-material-you-colors
# (python-material-color-utilities) and matugen (Rust) were picking their own,
# separately-computed source colors from the same image - close in hue but
# never matching the rest of the desktop's actual palette (kitty/GTK/Zen/etc,
# all driven by matugen's colors.json), which is what made dolphin/kcmshell6
# panels look "off-theme" even though they were reacting to wallpaper changes.
# Fixed by feeding it matugen's own already-computed "primary" color via
# --color instead of --file, so both tools build their M3 tonal palettes from
# the identical seed hue - the two implementations can still differ slightly
# in exact tonal math, but no longer diverge in hue/seed choice.
COLORS_JSON="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/colors.json"

scheme_variant=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --scheme-variant)
            scheme_variant="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# kde-material-you-colors --scheme-variant takes an integer:
# 0=Content 1=Expressive 2=Fidelity 3=Monochrome 4=Neutral 5=TonalSpot 6=Vibrant 7=Rainbow 8=FruitSalad
case "$scheme_variant" in
    scheme-content) sv=0 ;;
    scheme-expressive) sv=1 ;;
    scheme-fidelity) sv=2 ;;
    scheme-monochrome) sv=3 ;;
    scheme-neutral) sv=4 ;;
    scheme-tonal-spot) sv=5 ;;
    scheme-vibrant) sv=6 ;;
    scheme-rainbow) sv=7 ;;
    scheme-fruit-salad) sv=8 ;;
    *) sv=5 ;;
esac

[[ -f "$COLORS_JSON" ]] || exit 0
primary="$(jq -r '.primary' "$COLORS_JSON")"
[[ -n "$primary" && "$primary" != "null" ]] || exit 0

kde-material-you-colors --color "$primary" --scheme-variant "$sv" --dark
