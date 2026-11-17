#!/usr/bin/env bash
# "Config" entry of the app launcher: pick a config file, it opens in Neovim (in kitty).
# Add or remove a line below to change the list: "icon code|Label|path relative to ~/.config".
# (Icon codes are Nerd Font code points; they are turned into the glyph below.)
# Files that don't exist are skipped.
items=(
    "F0493|Hyprland|hypr/hyprland.lua"
    "F0379|Monitors|hypr/monitors.lua"
    "F030C|Keybinds|hypr/keybinds.lua"
    "F05B0|Window rules|hypr/rules.lua"
    "F03D8|Look and animations|hypr/decorations.lua"
    "F033E|Lock screen (hyprlock)|hypr/hyprlock.conf"
    "F04B2|Idle and suspend (hypridle)|hypr/hypridle-user.conf"
    "F08BB|Bar|bar/src/main.rs"
    "F057E|Volume popup|osd/src/main.rs"
    "F003B|Rofi|rofi/config.rasi"
    "F03D8|Rofi colors|rofi/colors.rasi"
    "F018D|Kitty|kitty/kitty.conf"
    "F0169|Neovim|nvim/init.lua"
    "F018D|Fish|fish/config.fish"
    "F08BB|Starship prompt|starship.toml"
    "F08BB|btop|btop/btop.conf"
    "F030C|Yazi keys|yazi/keymap.toml"
    "F05A9|Wi-Fi (impala)|impala/config.toml"
    "F00AF|Bluetooth (bluetui)|bluetui/config.toml"
    "F08BB|Fonts|fontconfig/fonts.conf"
    "F08BB|GTK|gtk-3.0/gtk.css"
)

# Started from the launcher, the launcher's rofi may still be closing; rofi won't start a second one yet.
for _ in $(seq 20); do pgrep -x rofi >/dev/null || break; sleep 0.05; done

labels=(); paths=()
for it in "${items[@]}"; do
    IFS='|' read -r code label rel <<<"$it"
    f="$HOME/.config/$rel"
    if [ -e "$f" ]; then
        printf -v icon "\\U000$code"
        labels+=("$icon   $label"); paths+=("$f")
    fi
done

i=$(printf '%s\n' "${labels[@]}" | rofi -dmenu -i -no-custom -format i -p "" \
    -theme-str 'element-icon { enabled: false; } window { height: 316px; } listview { lines: 5; }')
[ -n "$i" ] || exit 0
exec kitty nvim "${paths[$i]}"
