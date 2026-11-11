#!/usr/bin/env bash
# Keybind cheat sheet (Super+K): every shortcut with its keys, grouped and searchable.
# Reads ~/.config/hypr/keybinds.lua directly: each hl.bind("KEYS", ...) line is a shortcut, the
# trailing "-- comment" is its description, and "---- Heading ----" lines make the groups.
# Reference only: Enter or Esc closes it.
rows=$(python3 -I - "$HOME/.config/hypr/keybinds.lua" <<'EOF'
import re, sys, html
names = {"SUPER": "Super", "CTRL": "Ctrl", "SHIFT": "Shift", "ALT": "Alt"}
keys = {"Return": "Enter", "Grave": "`", "Escape": "Esc", "Space": "Space", "Print": "PrtSc"}
rows, group = [], ""
for line in open(sys.argv[1]):
    h = re.match(r'-{4}\s*(.*?)\s*(\(.*\))?\s*-*\s*$', line)
    if h:
        group = h.group(1).split(":")[0].strip()
        continue
    m = re.match(r'hl\.bind\("([^"]+)",.*?(?:--\s*(.*))?$', line.rstrip())
    if not m or "mouse:" in m.group(1) or "XF86" in m.group(1):
        continue
    combo = " + ".join(names.get(p, keys.get(p, p)) for p in m.group(1).split(" + "))
    rows.append((group, m.group(2) or "", combo))
rows += [("Mouse", "Move window", "Super + left drag"), ("Mouse", "Resize window", "Super + right drag"),
         ("Workspaces", "Go to workspace 1-10", "Super + 1-0"), ("Workspaces", "Send window to workspace 1-10", "Super + Shift + 1-0"),
         ("Media", "Volume / brightness", "media keys")]
w = max(len(r[1]) for r in rows) + 2
for g, l, k in rows:
    print(f"<span alpha='55%'>{html.escape(g):<15}</span>{html.escape(l):<{w}}<b>{html.escape(k)}</b>")
EOF
)
printf '%s\n' "$rows" | rofi -dmenu -i -markup-rows -no-custom -p "Keys" \
    -theme-str 'window { width: 760px; height: 640px; } listview { lines: 12; } element-icon { enabled: false; }' >/dev/null
