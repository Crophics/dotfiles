#!/usr/bin/env bash
# Suspend with the lid open. On this ThinkPad the embedded controller wakes
# s2idle within seconds unless acpi.ec_no_wakeup=1 (lid-close suspend is fine
# without it). A tmpfiles rule makes the switch writable by group wheel; it is
# turned on only for this sleep and restored afterwards.
EC=/sys/module/acpi/parameters/ec_no_wakeup
OK=/sys/power/suspend_stats/success
pidof hyprlock >/dev/null || { hyprlock & sleep 1.5; }
[ -w "$EC" ] && echo 1 > "$EC"
before=$(cat $OK)
systemctl suspend   # returns before the machine actually sleeps
# Wait for the sleep to finish. sleep() does not count time spent suspended,
# so this gives up only if no suspend happened within ~20s awake.
for _ in $(seq 40); do
    [ "$(cat $OK)" -gt "$before" ] && break
    sleep 0.5
done
[ -w "$EC" ] && echo 0 > "$EC"
