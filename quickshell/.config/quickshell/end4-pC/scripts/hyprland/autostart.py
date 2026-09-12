#!/usr/bin/env python3
import json, subprocess, time, os

# Scoped to the current Hyprland instance (changes every login/restart of
# Hyprland itself) rather than a fixed /tmp path - a fixed path only gets
# cleared by a full reboot (tmpfs), so any mid-session qs restart (crash,
# manual `pkill qs; qs -c ...`, testing, etc.) after the first autostart
# run would find the old lock still there and skip autostart for the rest
# of that Hyprland session, even after a real relogin if /tmp somehow
# wasn't cleared. Found stuck like this on 2026-09-11: lockfile from an
# earlier restart that same boot silently blocked every later one.
his = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', 'unknown')
lockfile = f"/tmp/qs-autostart-{his}.lock"
if os.path.exists(lockfile):
    exit(0)
open(lockfile, 'w').close()

with open(f"{os.environ['HOME']}/.config/illogical-impulse/config.json") as f:
    data = json.load(f)

autostart = data.get('hyprland', {}).get('autostartApps', {})
if not autostart.get('enable', False):
    exit(0)

for app in autostart.get('apps', []):
    cmd = app.get('cmd', '').strip()
    workspace = app.get('workspace', 1)
    delay = app.get('delay', 0)
    if not cmd:
        continue

    subprocess.run(['hyprctl', 'dispatch', f'hl.dsp.focus({{workspace = {workspace}}})'])

    expanded_cmd = os.path.expanduser(cmd)
    subprocess.Popen(
        ['hyprctl', 'dispatch', f'hl.dsp.exec_cmd("{expanded_cmd}")'],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        close_fds=True
    )

    time.sleep(delay)