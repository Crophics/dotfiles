#!/usr/bin/env bash
# Suspend the right way round: screen off at once, then the lock screen starts (drawn
# instantly, no fade-in) while the screen is dark, and only once it is fully there does
# the laptop go to sleep. Waking shows the finished lock screen straight away.
# Used by Super+Shift+L, the power menu, hypridle's suspend timer and the lock screen's sleep button.
# (Closing the lid goes through logind instead; hypridle locks before that sleep.)
hyprctl dispatch 'hl.dsp.dpms({action="off"})' >/dev/null
"$HOME/.config/qylock/lock.sh" --instant --wait
# If the suspend is refused (an app inhibits it), turn the screen back on.
systemctl suspend || hyprctl dispatch 'hl.dsp.dpms({action="on"})' >/dev/null
