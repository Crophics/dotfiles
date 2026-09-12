#!/usr/bin/env python3
"""Post-generation contrast fix for kde-material-you-colors' [Colors:Selection].

kde-material-you-colors (invoked by kde-material-you-colors-wrapper.sh,
seeded from matugen's color.txt) sets Selection BackgroundNormal/ForegroundNormal
straight from the Material 3 primary/onPrimary tone pair. That pair is
contrast-safe under default tone_multiplier/chroma_multiplier=1, but nothing
floors it if those config values (~/.config/kde-material-you-colors/config.conf)
are ever changed, since only background-flagged colors get the tone_multiplier
scaling applied to them -- their paired foreground does not.

This re-pins the Selection foreground roles to whichever of pure black/white
has the higher WCAG contrast ratio against the generated Selection background,
so selected filenames (e.g. in Dolphin) stay readable regardless of wallpaper
or those multiplier settings.
"""
import glob
import os
import re

SCHEME_GLOB = os.path.expanduser("~/.local/share/color-schemes/MaterialYou*.colors")
FG_KEYS = ("ForegroundNormal", "ForegroundActive", "ForegroundInactive")


def relative_luminance(hex_color):
    hex_color = hex_color.lstrip("#")
    r, g, b = (int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4))

    def lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = lin(r), lin(g), lin(b)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(hex_a, hex_b):
    la, lb = relative_luminance(hex_a), relative_luminance(hex_b)
    la, lb = max(la, lb), min(la, lb)
    return (la + 0.05) / (lb + 0.05)


def best_foreground(bg_hex):
    return "#ffffff" if contrast(bg_hex, "#ffffff") >= contrast(bg_hex, "#000000") else "#000000"


def patch_file(path):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    match = re.search(r"\[Colors:Selection\]\n(.*?)(?=\n\[|\Z)", text, re.DOTALL)
    if not match:
        return False
    block = match.group(1)

    bg_match = re.search(r"^BackgroundNormal=(#[0-9a-fA-F]{6})", block, re.MULTILINE)
    if not bg_match:
        return False
    fg = best_foreground(bg_match.group(1))

    new_block = block
    for key in FG_KEYS:
        new_block = re.sub(
            rf"^{key}=#[0-9a-fA-F]{{6}}",
            f"{key}={fg}",
            new_block,
            flags=re.MULTILINE,
        )

    if new_block == block:
        return False

    new_text = text[: match.start(1)] + new_block + text[match.end(1):]
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_text)
    return True


def main():
    for path in glob.glob(SCHEME_GLOB):
        patch_file(path)


if __name__ == "__main__":
    main()
