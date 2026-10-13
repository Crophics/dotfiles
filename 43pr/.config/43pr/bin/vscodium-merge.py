#!/usr/bin/env python3
"""Merge the generated Material Code colors into VSCodium's settings.json.

theme.py renders ~/.config/43pr/templates/vscodium-colors.json to ~/.cache/43pr/vscodium-colors.json and then
runs this script (target reload hook). Only the keys present in the generated file are replaced; every other
setting, and the key order, is left alone. Nothing is written if nothing changed."""
import json, os, sys, tempfile
from pathlib import Path

GEN = Path.home() / ".cache/43pr/vscodium-colors.json"
SETTINGS = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "VSCodium/User/settings.json"

def main():
    try:
        gen = json.loads(GEN.read_text())
    except Exception as e:
        print(f"vscodium-merge: cannot read {GEN}: {e}", file=sys.stderr); return 1
    try:
        cur = json.loads(SETTINGS.read_text()) if SETTINGS.exists() else {}
    except Exception as e:
        print(f"vscodium-merge: {SETTINGS} is not plain JSON ({e}); leaving it alone", file=sys.stderr); return 1
    new = dict(cur)
    new.update(gen)
    if new == cur:
        return 0
    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=SETTINGS.parent, prefix=".settings-", suffix=".json")
    with os.fdopen(fd, "w") as f:
        json.dump(new, f, indent=2); f.write("\n")
    os.replace(tmp, SETTINGS)
    return 0

if __name__ == "__main__":
    sys.exit(main())
