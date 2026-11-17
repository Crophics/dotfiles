#!/bin/bash
# Start Zen at login and tuck its first window into a special workspace, so later
# launches reuse the running process and open fast.
pgrep -x zen-bin >/dev/null && exit 0
zen-browser >/dev/null 2>&1 &
for _ in $(seq 1 100); do
    addr=$(hyprctl -j clients | python3 -c "
import sys, json
w = [c for c in json.load(sys.stdin) if c['class'] == 'zen']
print(w[0]['address'] if w else '')")
    if [ -n "$addr" ]; then
        hyprctl dispatch "hl.dsp.window.move({ workspace = \"special:preload\", follow = false, window = \"address:$addr\" })"
        exit 0
    fi
    sleep 0.2
done
