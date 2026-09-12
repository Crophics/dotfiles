#!/usr/bin/env bash
# Regenerates ~/.config/qt6ct/colors/noctalia.conf (the file qt6ct.conf's
# color_scheme_path actually points at) from the current Material colors,
# so qt6ct-styled Qt apps (dolphin, kde-cli-tools panels, etc.) pick up the
# wallpaper theme too. Previously done by skwd-wall's own matugen
# integration (now uninstalled); matugen's template engine can't do the
# hex->decimal-RGB conversion this KDE color-scheme format needs, so this
# is a small Python post-process step instead, matching the pattern
# generate_colors_material.py/applycolor.sh already use for kitty.
COLORS_JSON="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/colors.json"
OUT="$HOME/.config/qt6ct/colors/noctalia.conf"

[[ -f "$COLORS_JSON" ]] || exit 0
mkdir -p "$(dirname "$OUT")"

python3 - "$COLORS_JSON" "$OUT" << 'EOF'
import json, sys

colors_json, out_path = sys.argv[1], sys.argv[2]
c = json.load(open(colors_json))

def rgb(key):
    h = c[key].lstrip("#")
    return ",".join(str(int(h[i:i+2], 16)) for i in (0, 2, 4))

def hexc(key):
    return c[key]

def argb(key, alpha="ff"):
    return f"#{alpha}{c[key].lstrip('#')}"

# qt6ct's OWN native palette (read only when QT_QPA_PLATFORMTHEME=qt6ct,
# which is what this shell's Quickshell process - and everything it
# execDetach-launches, dolphin/kcmshell6 included - actually runs with, not
# "kde") is a completely different format from the Colors:* KDE/kdeglobals
# groups above: three flat lists of 21 "#AARRGGBB" tuples each, one per
# QPalette::ColorRole, in enum order (WindowText, Button, Light, Midlight,
# Dark, Mid, Text, BrightText, ButtonText, Base, Window, Shadow, Highlight,
# HighlightedText, Link, LinkVisited, AlternateBase, NoRole, ToolTipBase,
# ToolTipText, PlaceholderText) - confirmed against a real qt6ct-shipped
# scheme (/usr/share/qt6ct/colors/airy.conf). An earlier version of this
# script left these blank/wrong (11 decimal-RGB entries, no alpha channel),
# so qt6ct's custom_palette silently fell back to its default light Fusion
# palette - apps looked completely unstyled, not just off-color.
_active = [
    argb("on_surface"), argb("surface_container"), argb("surface_container_high"),
    argb("surface_container"), argb("surface_container_lowest"), argb("surface_variant"),
    argb("on_surface"), argb("on_primary_container"), argb("on_surface"), argb("surface"),
    argb("surface"), argb("scrim"), argb("primary"), argb("on_primary"), argb("primary"),
    argb("tertiary"), argb("surface_container_low"), argb("surface"),
    argb("surface_container_high"), argb("on_surface"), argb("on_surface_variant"),
]
_disabled = [
    argb("outline"), argb("surface_container"), argb("surface_container_high"),
    argb("surface_container"), argb("surface_container_lowest"), argb("surface_variant"),
    argb("outline"), argb("outline"), argb("outline"), argb("surface"),
    argb("surface"), argb("scrim"), argb("surface_container_high"), argb("outline"),
    argb("outline"), argb("outline"), argb("surface_container_low"), argb("surface"),
    argb("surface_container_high"), argb("outline"), argb("outline"),
]
active_colors_line = ", ".join(_active)
disabled_colors_line = ", ".join(_disabled)
inactive_colors_line = active_colors_line

group = lambda bg_alt, bg, fg_normal, fg_active, fg_inactive, fg_neutral, fg_link: f"""BackgroundAlternate={bg_alt}
BackgroundNormal={bg}
DecorationFocus={rgb('primary')}
DecorationHover={rgb('primary')}
ForegroundActive={fg_active}
ForegroundInactive={fg_inactive}
ForegroundLink={fg_link}
ForegroundNegative={rgb('error')}
ForegroundNeutral={fg_neutral}
ForegroundNormal={fg_normal}
ForegroundPositive={fg_active}
ForegroundVisited={fg_link}"""

surface = rgb("surface")
surface_container = rgb("surface_container")
surface_container_low = rgb("surface_container_low")
on_surface = rgb("on_surface")
on_surface_variant = rgb("on_surface_variant")
outline = rgb("outline")
primary = rgb("primary")
on_primary = rgb("on_primary")
tertiary = rgb("tertiary")

out = f"""[ColorScheme]
active_colors={active_colors_line}
disabled_colors={disabled_colors_line}
inactive_colors={inactive_colors_line}

[ColorEffects:Disabled]
Color={on_surface_variant}
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color={on_surface_variant}
ColorAmount=0.025
ColorEffect=2
ContrastAmount=0.1
ContrastEffect=2
Enable=false
IntensityAmount=0
IntensityEffect=0

[Colors:Button]
{group(surface_container, surface_container, on_surface, primary, on_surface_variant, on_surface_variant, tertiary)}

[Colors:Complementary]
{group(surface_container, surface, on_surface, primary, on_surface_variant, on_surface_variant, tertiary)}

[Colors:Header]
{group(surface_container, surface, on_surface, primary, on_surface_variant, on_surface_variant, tertiary)}

[Colors:Header][Inactive]
{group(surface_container, surface, on_surface, primary, on_surface_variant, on_surface_variant, tertiary)}

[Colors:Selection]
BackgroundAlternate={primary}
BackgroundNormal={primary}
DecorationFocus={primary}
DecorationHover={primary}
ForegroundActive={on_primary}
ForegroundInactive={on_primary}
ForegroundLink={on_primary}
ForegroundNegative={rgb('on_error')}
ForegroundNeutral={on_primary}
ForegroundNormal={on_primary}
ForegroundPositive={on_primary}
ForegroundVisited={on_primary}

[Colors:Tooltip]
{group(surface_container, surface_container, on_surface, primary, on_surface_variant, on_surface_variant, tertiary)}

[Colors:View]
{group(surface_container_low, surface, on_surface, primary, on_surface_variant, on_surface_variant, tertiary)}

[Colors:Window]
{group(surface_container, surface, on_surface, primary, on_surface_variant, on_surface_variant, tertiary)}

[WM]
activeBackground={surface}
activeBlend={on_surface}
activeForeground={on_surface}
inactiveBackground={surface}
inactiveBlend={on_surface_variant}
inactiveForeground={on_surface_variant}
"""

with open(out_path, "w") as f:
    f.write(out)
EOF
