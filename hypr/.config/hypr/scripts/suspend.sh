#!/usr/bin/env bash
# Suspend, and retry if the laptop wakes by itself within seconds.
# Needed because this ThinkPad's embedded controller wakes s2idle at once
# when suspended with the lid open (closing the lid is fine).
pidof hyprlock >/dev/null || { hyprlock & sleep 1; }
for _ in 1 2 3; do
    start=$(date +%s)
    systemctl suspend
    [ $(( $(date +%s) - start )) -ge 20 ] && break
    sleep 2
done
