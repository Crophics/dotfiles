#!/usr/bin/env bash
# Keybind cheat sheet (Super+K): every shortcut with its current keys, grouped and searchable.
# Reads the live binds (binds.lua, written by Settings > Keybinds) and the labels from keybind-defaults.json,
# so it always matches what's actually bound. Reference only: Enter or Esc closes it.
rows=$(python3 -I - "$HOME/.config/hypr" <<'EOF'
import json, re, sys, html
d = sys.argv[1]
labels = {x["id"]: (x["group"], x["label"]) for x in json.load(open(d + "/keybind-defaults.json"))}
try:
    src = open(d + "/binds.lua").read()
except OSError:
    src = open(d + "/binds-default.lua").read()
names = {"SUPER": "Super", "CTRL": "Ctrl", "SHIFT": "Shift", "ALT": "Alt"}
keys = {"Return": "Enter", "Grave": "`", "Escape": "Esc", "Space": "Space", "Print": "PrtSc"}
def combo(mods, key):
    return " + ".join([names.get(m, m) for m in mods] + ([keys.get(key, key)] if key else []))
rows = []
for m in re.finditer(r'\{\s*id = "([^"]+)",\s*mods = \{([^}]*)\},\s*key = "([^"]*)",\s*enabled = (true|false)(.*?)\}', src):
    bid, mods, key, on, rest = m.groups()
    if on != "true":
        continue
    mods = re.findall(r'"([^"]+)"', mods)
    group, label = labels.get(bid, ("Custom", bid))
    cmd = re.search(r'command = "([^"]*)"', rest)
    if cmd and bid not in labels:
        label = cmd.group(1)
    if bid in ("ws-focus", "ws-move"):
        key = "1-0"
    if not key and bid not in ("ws-focus", "ws-move"):
        continue
    rows.append((group, label, combo(mods, key)))
rows += [("Mouse", "Move window", "Super + left drag"), ("Mouse", "Resize window", "Super + right drag"),
         ("Media", "Volume / brightness", "media keys")]
w = max(len(r[1]) for r in rows) + 2
for g, l, k in rows:
    print(f"<span alpha='55%'>{html.escape(g):<15}</span>{html.escape(l):<{w}}<b>{html.escape(k)}</b>")
EOF
)
printf '%s\n' "$rows" | rofi -dmenu -i -markup-rows -no-custom -p "Keys" \
    -theme-str 'window { width: 760px; height: 640px; } listview { lines: 12; } element-icon { enabled: false; }' >/dev/null
