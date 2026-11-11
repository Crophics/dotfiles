#!/usr/bin/env bash
# Simple rofi power menu (Super+Escape and the bar's power button).
# Icons are Nerd Font code points written as escapes, so editors can't strip them.
lock=$'\U000F033E'; suspend=$'\U000F0904'; logout=$'\U000F0343'; reboot=$'\U000F0709'; off=$'\U000F0425'
choice="$(printf '%s\n' "$lock   Lock" "$suspend   Suspend" "$logout   Log out" "$reboot   Reboot" "$off   Shut down" \
    | rofi -dmenu -i -no-custom -p "" -theme "$HOME/.config/rofi/powermenu.rasi")"
case "$choice" in
    *Lock)        loginctl lock-session ;;
    *Suspend)     exec "$HOME/.config/qylock/suspend.sh" ;;
    *"Log out")   hyprctl dispatch 'hl.dsp.exit()' ;;
    *Reboot)      systemctl reboot ;;
    *"Shut down") systemctl poweroff ;;
esac
