#!/usr/bin/env bash
# Manual / idle suspend: lock first (wait until the lock covers the screen), then sleep.
# The marker tells sleep-hook.sh this was deliberate, so the wake stays locked.
~/.config/qylock/lock.sh --wait
touch "${XDG_RUNTIME_DIR:-/tmp}/sleep-manual"
systemctl suspend
