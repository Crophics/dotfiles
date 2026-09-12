#!/usr/bin/env bash
# Subtle Zen Browser accent theming from the wallpaper - just the native
# zen.theme.accent-color pref (drives --zen-primary-color, used for button/
# active-element accents) plus the standard Firefox active/anchor color
# prefs. NOT touching Zen's own "ZenMods" userChrome system (chrome/zen-themes*)
# - that's user-managed via Zen's own Mods UI, this only sets prefs via
# user.js (read once at browser startup, like any other Firefox override).
exec 200>/tmp/set-zen-colors.lock
flock -n 200 || exit 0

COLORS_JSON="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/colors.json"
PROFILE_DIR="$HOME/.config/zen/bscizgd2.Default (release)"
USER_JS="$PROFILE_DIR/user.js"

[[ -f "$COLORS_JSON" ]] || exit 0
[[ -d "$PROFILE_DIR" ]] || exit 0

primary=$(jq -r '.primary' "$COLORS_JSON")
secondary=$(jq -r '.secondary' "$COLORS_JSON")

NEW_BLOCK=$(cat <<EOF
// AUTOGEN-COLORS-START
user_pref("zen.theme.accent-color", "${primary}");
user_pref("browser.active_color.dark", "${primary}");
user_pref("browser.anchor_color.dark", "${secondary}");
// AUTOGEN-COLORS-END
EOF
)

touch "$USER_JS"
if grep -q "AUTOGEN-COLORS-START" "$USER_JS"; then
    awk -v block="$NEW_BLOCK" '
        /\/\/ AUTOGEN-COLORS-START/ {print block; skip=1; next}
        /\/\/ AUTOGEN-COLORS-END/ {skip=0; next}
        !skip {print}
    ' "$USER_JS" > "${USER_JS}.tmp" && mv "${USER_JS}.tmp" "$USER_JS"
else
    printf '\n%s\n' "$NEW_BLOCK" >> "$USER_JS"
fi
