#!/usr/bin/env bash
COLOR_FILE_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/material_colors.scss"

# Define an array of possible VSCode settings file paths for various forks
settings_paths=(
    "${XDG_CONFIG_HOME:-$HOME/.config}/Code/User/settings.json"
    "${XDG_CONFIG_HOME:-$HOME/.config}/VSCodium/User/settings.json"
    "${XDG_CONFIG_HOME:-$HOME/.config}/Code - OSS/User/settings.json"
    "${XDG_CONFIG_HOME:-$HOME/.config}/Code - Insiders/User/settings.json"
    "${XDG_CONFIG_HOME:-$HOME/.config}/Cursor/User/settings.json"
    "${XDG_CONFIG_HOME:-$HOME/.config}/Antigravity/User/settings.json"
    "${XDG_CONFIG_HOME:-$HOME/.config}/Windsurf/User/settings.json"
    
    # Add more paths as needed for other forks
)

# Use the same Material You role tokens the terminal (kitty) colorscheme is
# built from, so the editor accent/syntax colors match the rest of the
# desktop instead of the raw unprocessed wallpaper seed color.
get_token() {
    grep -m1 "^\\\$${1}:" "$COLOR_FILE_PATH" | grep -oE '#[0-9A-Fa-f]{6}'
}
new_color=$(get_token primary)
color_secondary=$(get_token secondary)
color_tertiary=$(get_token tertiary)
color_error=$(get_token error)
color_success=$(get_token success)

# material-code.primaryColor only drives UI chrome (activity bar, buttons,
# badges). Syntax highlighting is intentionally NOT derived from the
# wallpaper palette: Material You's primary/secondary/tertiary/error/success
# tokens are all close in tone (one seed hue), so mapping 7 syntax
# categories onto only 5 tokens produced duplicate/near-identical colors
# (keyword==property, variable==function) and made tokens hard to tell
# apart. Syntax colors are pinned to a fixed high-contrast palette instead
# (loosely One Dark Pro) so they stay legible and stable across wallpaper
# changes.
#
# background/card/popover are pinned to a fixed neutral dark instead of the
# wallpaper-derived tone - VSCodium (Electron) doesn't support real per-pixel
# window transparency, so an alpha=0 hex here just renders as a broken solid
# color block. Hyprland's window-level opacity/blur already handles the
# see-through effect for the whole window regardless of these values; this
# just stops the panels from ALSO being hue-tinted on top of that.
colors_json=$(jq -n \
    '{background: "#1a1a1a", card: "#202020", popover: "#242424",
      syntax: {comment: "#6B7280", keyword: "#C678DD", variable: "#D6D4D5", attribute: "#E5C07B", property: "#56B6C2", function: "#61AFEF", string: "#98C379", constant: "#D19A66"}}')

# Loop through each settings file path
for CODE_SETTINGS_PATH in "${settings_paths[@]}"; do
    if [[ -f "$CODE_SETTINGS_PATH" ]]; then
        if jq empty "$CODE_SETTINGS_PATH" 2>/dev/null; then
            # Valid JSON (no JSONC comments) - safe to update both keys with jq
            tmp_file="${CODE_SETTINGS_PATH}.tmp"
            jq --arg primary "$new_color" --argjson colors "$colors_json" \
                '.["material-code.primaryColor"] = $primary | .["material-code.colors"] = $colors' \
                "$CODE_SETTINGS_PATH" > "$tmp_file" && mv "$tmp_file" "$CODE_SETTINGS_PATH"
        elif grep -q '"material-code.primaryColor"' "$CODE_SETTINGS_PATH"; then
            # Fall back to a surgical text replace for files jq can't parse (e.g. JSONC comments)
            sed -i -E \
                "s/(\"material-code.primaryColor\"\s*:\s*\")[^\"]*(\")/\1${new_color}\2/" \
                "$CODE_SETTINGS_PATH"
        else
            sed -i '$ s/}/,\n  "material-code.primaryColor": "'${new_color}'"\n}/' "$CODE_SETTINGS_PATH"
            sed -i '$ s/,\n,/,/' "$CODE_SETTINGS_PATH"
        fi
    fi
done

