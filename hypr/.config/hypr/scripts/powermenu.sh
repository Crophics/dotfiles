#!/usr/bin/env bash
# Simple rofi power menu (Super+Escape and the bar's power button).
choice="$(printf '%s\n' "  Lock" "󰤄  Suspend" "󰍃  Log out" "  Reboot" "  Shut down" \
    | rofi -dmenu -p "⏻" -i -no-custom -l 5 -theme-str 'window { height: 260px; }')"
case "$choice" in
    *Lock)        loginctl lock-session ;;
    *Suspend)     "$HOME/.config/hypr/scripts/suspend.sh" ;;
    *"Log out")   hyprctl dispatch 'hl.dsp.exit()' ;;
    *Reboot)      systemctl reboot ;;
    *"Shut down") systemctl poweroff ;;
esac
