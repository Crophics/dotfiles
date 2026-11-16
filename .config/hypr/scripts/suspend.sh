#!/usr/bin/env bash
# Suspend: screen off at once, hyprlock starts (no fade-in) while the screen is dark,
# then the laptop sleeps. Waking shows the finished lock screen straight away.
# Used by Super+Shift+L, the power menu, hypridle's suspend timer and the lock screen's sleep button.
hyprctl dispatch 'hl.dsp.dpms({action="off"})' >/dev/null
hyprlock --no-fade-in &
sleep 1
systemctl suspend || hyprctl dispatch 'hl.dsp.dpms({action="on"})' >/dev/null
