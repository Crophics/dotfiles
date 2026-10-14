#!/usr/bin/env python3
"""Night light through hyprsunset, with an optional daily schedule.

  nightlight.py daemon                 keep the screen in step with the schedule (run at login)
  nightlight.py status                 print the state as JSON (on = what the screen is doing now)
  nightlight.py toggle on|off          turn it on or off right now
  nightlight.py temp <K> [preview]     set the warmth; "preview" shows it even while off, without saving
  nightlight.py auto on|off            switch the schedule on or off
  nightlight.py times <HH:MM> <HH:MM>  when the schedule turns it on and off
  nightlight.py apply                  apply the saved state once

State is quickshell/state/nightlight.json. Changes go through hyprsunset's socket, so the
screen never flashes back to normal colours. While the schedule is on, a manual toggle holds
until the next scheduled switch.
"""
import datetime, fcntl, json, os, subprocess, sys, time

HOME = os.path.expanduser("~")
STATE = f"{HOME}/.config/quickshell/state/nightlight.json"
PREVIEW = f"{HOME}/.cache/nightlight.preview"
DEFAULT = {"enabled": False, "temp": 4500, "auto": False, "start": "20:00", "end": "07:00", "ovr": None, "sched": None}


def load():
    try:
        with open(STATE) as f:
            return {**DEFAULT, **json.load(f)}
    except (OSError, ValueError):
        return dict(DEFAULT)


def save(s):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(s, f)
    os.replace(tmp, STATE)


def minutes(hhmm):
    h, m = hhmm.split(":")
    return int(h) * 60 + int(m)


def in_window(s, now=None):
    now = now or datetime.datetime.now()
    t, a, b = now.hour * 60 + now.minute, minutes(s["start"]), minutes(s["end"])
    return (a <= t < b) if a < b else (t >= a or t < b)


def effective(s):
    """Whether night light should be on now. Updates s (override bookkeeping) in place."""
    if not s["auto"]:
        return s["enabled"]
    sch = in_window(s)
    if s["sched"] is not None and s["sched"] != sch:
        s["ovr"] = None          # a scheduled switch happened; manual hold is over
    s["sched"] = sch
    return sch if s["ovr"] is None else s["ovr"]


def running():
    return subprocess.run(["pgrep", "-x", "hyprsunset"], capture_output=True).returncode == 0


def sunset(*args):
    return subprocess.run(["hyprctl", "hyprsunset", *args], capture_output=True).returncode == 0


def show(on, temp):
    if not running():
        if not on:
            return
        subprocess.Popen(["hyprsunset", "-t", str(temp)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
        return
    sunset("temperature", str(temp)) if on else sunset("identity")


def apply(s):
    on = effective(s)
    save(s)
    show(on, s["temp"])
    return on


def main():
    a = sys.argv[1:]
    cmd = a[0] if a else ""
    s = load()
    if cmd == "daemon":
        lock = open(f"{HOME}/.cache/nightlight.lock", "w")
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            return
        while True:
            try:
                previewing = time.time() - os.path.getmtime(PREVIEW) < 4
            except OSError:
                previewing = False
            if not previewing:
                apply(load())
            time.sleep(2 if previewing else 15)
    elif cmd == "status":
        on = effective(s)
        print(json.dumps({**s, "on": on}))
    elif cmd == "toggle" and len(a) == 2:
        want = a[1] == "on"
        if s["auto"]:
            sch = in_window(s)
            s["ovr"] = None if want == sch else want
            s["sched"] = sch
        else:
            s["enabled"] = want
        apply(s)
    elif cmd == "temp" and len(a) >= 2:
        t = max(1000, min(10000, int(a[1])))
        if len(a) > 2 and a[2] == "preview":
            show(True, t)                      # even while off; the next saved change puts it back
            open(PREVIEW, "w").close()         # tells the daemon to leave the screen alone for a moment
        else:
            s["temp"] = t
            apply(s)
    elif cmd == "auto" and len(a) == 2:
        s["auto"] = a[1] == "on"
        s["ovr"] = None
        s["sched"] = None
        if s["auto"]:
            s["enabled"] = s["enabled"]
        apply(s)
    elif cmd == "times" and len(a) == 3:
        minutes(a[1]); minutes(a[2])
        s["start"], s["end"], s["ovr"], s["sched"] = a[1], a[2], None, None
        apply(s)
    elif cmd == "apply":
        apply(s)
    else:
        sys.exit(__doc__)


main()
