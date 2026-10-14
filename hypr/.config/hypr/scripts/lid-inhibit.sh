#!/usr/bin/env bash
# Stops logind from suspending on lid close while Hyprland runs; lid.sh does it instead.
# Exits (releasing the block) when Hyprland is gone, so a crash can't leave the lid ignored.
pgrep -f "[l]id-inhibit-hold" >/dev/null && exit 0
exec systemd-inhibit --what=handle-lid-switch --who="hyprland lid" --why="lid.sh handles the lid" --mode=block \
    bash -c 'exec -a lid-inhibit-hold bash -c "while pgrep -x Hyprland >/dev/null; do sleep 5; done"'
