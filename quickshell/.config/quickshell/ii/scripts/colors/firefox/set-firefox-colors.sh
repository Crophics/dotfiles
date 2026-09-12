#!/usr/bin/env bash
exec 200>/tmp/set-firefox-colors.lock
flock -n 200 || exit 0
COLORS_JSON="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/colors.json"
PROFILE_DIR="$HOME/.config/mozilla/firefox/zu7j29qh.default-release"
USERCHROME="$PROFILE_DIR/chrome/userChrome.css"

[[ -f "$COLORS_JSON" ]] || exit 0
[[ -f "$USERCHROME" ]] || exit 0

bg=$(jq -r '.surface_container_low' "$COLORS_JSON")
fg=$(jq -r '.on_surface' "$COLORS_JSON")
accent=$(jq -r '.primary' "$COLORS_JSON")
accent_container=$(jq -r '.primary_container' "$COLORS_JSON")
on_accent_container=$(jq -r '.on_primary_container' "$COLORS_JSON")
urlbar_bg=$(jq -r '.surface_container' "$COLORS_JSON")
urlbar_border=$(jq -r '.outline_variant' "$COLORS_JSON")

NEW_BLOCK=$(cat <<EOF
/* AUTOGEN-COLORS-START */
:root {
    --toolbar-bg: ${bg};
    --toolbar-fg: ${fg};
    --toolbar-accent: ${accent};
    --toolbar-accent-container: ${accent_container};
    --toolbar-on-accent-container: ${on_accent_container};
}

#nav-bar {
    background-color: var(--toolbar-bg) !important;
    color: var(--toolbar-fg) !important;
}

#TabsToolbar {
    background-color: var(--toolbar-bg) !important;
}

/* Firefox 155's tab elements don't reliably inherit :root custom properties
   (its own tokens are defined on ":root, :host" - suggesting the tabs live
   in a shadow-DOM-like scope :root alone doesn't reach). A var() that fails
   to resolve invalidates the whole declaration, silently falling back to
   Firefox's default - confirmed by testing: a literal color worked here,
   var(--toolbar-accent-container) did not. So these use literal hex values
   instead of the custom properties above. Selector itself confirmed from
   Firefox's own source (tabbrowser/tab.js + tabs.css): the [selected]
   attribute is forwarded onto .tab-background directly, not inherited from
   an ancestor .tabbrowser-tab[selected].
   Material "container" role instead of the flat pastel primary - richer and
   more legible, especially once blended by the desktop's window transparency. */
.tab-background:is([selected], [multiselected]) {
    background-color: ${accent_container} !important;
    border-bottom: 2px solid ${accent} !important;
}

.tab-content:is([selected], [multiselected]) .tab-text {
    color: ${on_accent_container} !important;
}

#urlbar-background {
    background-color: ${urlbar_bg} !important;
    border-color: ${urlbar_border} !important;
}
/* AUTOGEN-COLORS-END */
EOF
)

awk -v block="$NEW_BLOCK" '
    /\/\* AUTOGEN-COLORS-START \*\// {print block; skip=1; next}
    /\/\* AUTOGEN-COLORS-END \*\// {skip=0; next}
    !skip {print}
' "$USERCHROME" > "${USERCHROME}.tmp" && mv "${USERCHROME}.tmp" "$USERCHROME"