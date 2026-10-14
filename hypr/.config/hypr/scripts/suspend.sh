#!/usr/bin/env bash
# Suspend: lock first (wait until the lock covers the screen), then sleep.
# hypridle also locks before any sleep (power button etc.); this makes sure it happens first.
~/.config/qylock/lock.sh --wait
systemctl suspend
